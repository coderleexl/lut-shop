import Foundation
import Network

struct CameraReceivedFile: Equatable {
    var fileURL: URL
    var originalFileName: String
}

final class CameraReceiveService {
    enum ServiceError: Error {
        case listenerUnavailable
    }

    var onFileReceived: ((CameraReceivedFile) -> Void)?
    var onTransferStarted: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let queue = DispatchQueue(label: "com.lutshop.camera-receive")
    private var commandListener: NWListener?
    private var activeConnections: [ObjectIdentifier: FTPControlSession] = [:]

    var isRunning: Bool {
        commandListener != nil
    }

    func start(configuration: FtpReceiverConfiguration, host: String) throws {
        stop()

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: UInt16(configuration.port))!)
        commandListener = listener

        listener.newConnectionHandler = { [weak self] connection in
            self?.queue.async {
                self?.handle(connection: connection, configuration: configuration, host: host)
            }
        }
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                self?.onError?("FTP receiver failed: \(error.localizedDescription)")
                self?.stop()
            }
        }
        listener.start(queue: queue)
    }

    func stop() {
        commandListener?.cancel()
        commandListener = nil
        activeConnections.values.forEach { $0.stop() }
        activeConnections.removeAll()
    }

    private func handle(connection: NWConnection, configuration: FtpReceiverConfiguration, host: String) {
        let session = FTPControlSession(
            connection: connection,
            configuration: configuration,
            host: host,
            queue: queue,
            transferStartedHandler: { [weak self] fileName in
                self?.onTransferStarted?(fileName)
            },
            fileHandler: { [weak self] file in
                self?.onFileReceived?(file)
            },
            closeHandler: { [weak self, weak connection] in
                guard let connection else { return }
                self?.queue.async {
                    self?.activeConnections.removeValue(forKey: ObjectIdentifier(connection))
                }
            }
        )
        activeConnections[ObjectIdentifier(connection)] = session
        session.start()
    }
}

private final class FTPControlSession {
    private let connection: NWConnection
    private let configuration: FtpReceiverConfiguration
    private let host: String
    private let queue: DispatchQueue
    private let transferStartedHandler: (String) -> Void
    private let fileHandler: (CameraReceivedFile) -> Void
    private let closeHandler: () -> Void
    private var commandBuffer = Data()
    private var passiveListener: NWListener?
    private var pendingDataConnection: NWConnection?

    init(
        connection: NWConnection,
        configuration: FtpReceiverConfiguration,
        host: String,
        queue: DispatchQueue,
        transferStartedHandler: @escaping (String) -> Void,
        fileHandler: @escaping (CameraReceivedFile) -> Void,
        closeHandler: @escaping () -> Void
    ) {
        self.connection = connection
        self.configuration = configuration
        self.host = host
        self.queue = queue
        self.transferStartedHandler = transferStartedHandler
        self.fileHandler = fileHandler
        self.closeHandler = closeHandler
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.send("220 lut-shop FTP receiver ready")
                self?.receiveCommands()
            case .failed, .cancelled:
                self?.stop()
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func stop() {
        passiveListener?.cancel()
        passiveListener = nil
        pendingDataConnection?.cancel()
        pendingDataConnection = nil
        connection.cancel()
        closeHandler()
    }

    private func receiveCommands() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.commandBuffer.append(data)
                self.consumeBufferedCommands()
            }
            if isComplete || error != nil {
                self.stop()
            } else {
                self.receiveCommands()
            }
        }
    }

    private func consumeBufferedCommands() {
        while let range = commandBuffer.firstCRLFRange() {
            let lineData = commandBuffer.subdata(in: 0..<range.lowerBound)
            commandBuffer.removeSubrange(0..<range.upperBound)
            guard let line = String(data: lineData, encoding: .utf8) else { continue }
            handle(commandLine: line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func handle(commandLine: String) {
        guard !commandLine.isEmpty else { return }
        let parts = commandLine.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let command = parts[0].uppercased()
        let argument = parts.count > 1 ? String(parts[1]) : ""

        switch command {
        case "USER":
            send(argument == configuration.username ? "331 Password required" : "530 Invalid username")
        case "PASS":
            send(argument == configuration.password ? "230 Login successful" : "530 Invalid password")
        case "SYST":
            send("215 UNIX Type: L8")
        case "FEAT":
            send("211-Features\r\n EPSV\r\n PASV\r\n UTF8\r\n211 End")
        case "PWD", "XPWD":
            send("257 \"/\" is the current directory")
        case "CWD":
            send("250 Directory changed")
        case "TYPE":
            send("200 Type set")
        case "MODE":
            send("200 Mode set")
        case "STRU":
            send("200 Structure set")
        case "NOOP":
            send("200 OK")
        case "PASV":
            openPassiveListener(useExtendedResponse: false)
        case "EPSV":
            openPassiveListener(useExtendedResponse: true)
        case "STOR":
            receiveFile(named: argument)
        case "QUIT":
            send("221 Bye")
            stop()
        default:
            send("502 Command not implemented")
        }
    }

    private func openPassiveListener(useExtendedResponse: Bool) {
        passiveListener?.cancel()
        pendingDataConnection = nil

        do {
            let listener = try NWListener(using: .tcp, on: .any)
            passiveListener = listener
            listener.newConnectionHandler = { [weak self] connection in
                self?.pendingDataConnection = connection
            }
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                if case .ready = state, let port = listener.port?.rawValue {
                    if useExtendedResponse {
                        self.send("229 Entering Extended Passive Mode (|||\(port)|)")
                    } else {
                        let bytes = self.passiveAddressBytes()
                        let high = Int(port) / 256
                        let low = Int(port) % 256
                        self.send("227 Entering Passive Mode (\(bytes.0),\(bytes.1),\(bytes.2),\(bytes.3),\(high),\(low))")
                    }
                }
            }
            listener.start(queue: queue)
        } catch {
            send("425 Cannot open passive connection")
        }
    }

    private func receiveFile(named rawName: String) {
        let fileName = sanitizedFileName(rawName)
        guard let dataConnection = pendingDataConnection else {
            send("425 Use PASV or EPSV first")
            return
        }

        transferStartedHandler(fileName)
        send("150 Opening data connection")
        let targetURL: URL
        do {
            targetURL = try makeInboxURL(fileName: fileName)
        } catch {
            send("451 Cannot create target file")
            return
        }

        dataConnection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                self?.receiveData(on: dataConnection, payload: Data(), targetURL: targetURL, originalFileName: fileName)
            }
        }
        dataConnection.start(queue: queue)
    }

    private func receiveData(
        on dataConnection: NWConnection,
        payload: Data,
        targetURL: URL,
        originalFileName: String
    ) {
        dataConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var nextPayload = payload
            if let data, !data.isEmpty {
                nextPayload.append(data)
            }

            if isComplete || error != nil {
                do {
                    try nextPayload.write(to: targetURL, options: .atomic)
                    self.fileHandler(CameraReceivedFile(fileURL: targetURL, originalFileName: originalFileName))
                    self.send("226 Transfer complete")
                } catch {
                    self.send("451 File write failed")
                }
                dataConnection.cancel()
                self.pendingDataConnection = nil
                self.passiveListener?.cancel()
                self.passiveListener = nil
            } else {
                self.receiveData(on: dataConnection, payload: nextPayload, targetURL: targetURL, originalFileName: originalFileName)
            }
        }
    }

    private func send(_ message: String) {
        guard let data = "\(message)\r\n".data(using: .utf8) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private func passiveAddressBytes() -> (Int, Int, Int, Int) {
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return (127, 0, 0, 1) }
        return (parts[0], parts[1], parts[2], parts[3])
    }

    private func makeInboxURL(fileName: String) throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent("CameraReceiveInbox", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let timestamp = Int(Date().timeIntervalSince1970)
        return directory.appendingPathComponent("\(timestamp)-\(fileName)")
    }

    private func sanitizedFileName(_ rawName: String) -> String {
        let fallback = "camera-upload"
        let lastPathComponent = (rawName as NSString).lastPathComponent
        let candidate = lastPathComponent.isEmpty ? fallback : lastPathComponent
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let sanitized = String(candidate.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_."))
        return sanitized.isEmpty ? fallback : sanitized
    }
}

private extension Data {
    func firstCRLFRange() -> Range<Int>? {
        guard count >= 2 else { return nil }
        for index in 0..<(count - 1) where self[index] == 13 && self[index + 1] == 10 {
            return index..<(index + 2)
        }
        return nil
    }
}

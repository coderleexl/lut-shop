import Foundation
import Network

struct DiscoveredCameraEndpoint: Equatable {
    var name: String
    var serviceType: String
    var host: String
    var port: Int
}

final class CameraDiscoveryService {
    private var browsers: [NWBrowser] = []
    private var endpointsByServiceType: [String: [DiscoveredCameraEndpoint]] = [:]
    private let queue = DispatchQueue(label: "com.lutshop.camera-discovery")

    func start(onUpdate: @escaping ([DiscoveredCameraEndpoint]) -> Void) {
        stop()

        let serviceTypes = ["_ftp._tcp", "_sftp-ssh._tcp"]
        for serviceType in serviceTypes {
            let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: .tcp)
            browser.browseResultsChangedHandler = { results, _ in
                let endpoints = results.compactMap { result -> DiscoveredCameraEndpoint? in
                    guard case let .service(name, type, domain, interface) = result.endpoint else {
                        return nil
                    }
                    let host = interface.map { "\($0)" } ?? domain
                    let port = type == "_sftp-ssh._tcp" ? 22 : 21
                    return DiscoveredCameraEndpoint(
                        name: name,
                        serviceType: type,
                        host: host,
                        port: port
                    )
                }

                self.endpointsByServiceType[serviceType] = endpoints
                let allEndpoints = self.endpointsByServiceType.values.flatMap { $0 }
                DispatchQueue.main.async {
                    onUpdate(allEndpoints)
                }
            }
            browser.start(queue: queue)
            browsers.append(browser)
        }
    }

    func stop() {
        browsers.forEach { $0.cancel() }
        browsers.removeAll()
        endpointsByServiceType.removeAll()
    }
}

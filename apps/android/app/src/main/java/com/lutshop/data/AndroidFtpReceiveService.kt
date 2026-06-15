package com.lutshop.data

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.io.PrintWriter
import java.net.Inet4Address
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import java.util.Locale

data class CameraReceivedFile(
    val file: File,
    val originalFileName: String
)

class AndroidFtpReceiveService(
    private val context: Context,
    private val scope: CoroutineScope,
    private val onTransferStarted: (String) -> Unit,
    private val onFileReceived: (CameraReceivedFile) -> Unit,
    private val onError: (String) -> Unit
) {
    private var serverSocket: ServerSocket? = null
    private var serverJob: Job? = null

    val isRunning: Boolean
        get() = serverSocket?.isClosed == false

    fun start(configuration: FtpReceiverConfiguration) {
        stop()
        serverJob = scope.launch(Dispatchers.IO) {
            runCatching {
                ServerSocket(configuration.port).use { server ->
                    server.reuseAddress = true
                    serverSocket = server
                    while (isActive) {
                        val socket = server.accept()
                        launch { handleClient(socket, configuration) }
                    }
                }
            }.onFailure { error ->
                if (isActive) withContext(Dispatchers.Main) { onError(error.localizedMessage ?: "FTP receiver failed") }
            }
            serverSocket = null
        }
    }

    fun stop() {
        val job = serverJob
        serverJob = null
        job?.cancel()
        serverSocket?.close()
        serverSocket = null
        if (job != null) {
            scope.launch(Dispatchers.IO) { job.cancelAndJoin() }
        }
    }

    private fun handleClient(socket: Socket, configuration: FtpReceiverConfiguration) {
        socket.use { control ->
            val reader = BufferedReader(InputStreamReader(control.getInputStream(), Charsets.UTF_8))
            val writer = PrintWriter(control.getOutputStream(), true)
            var authenticated = false
            var passiveServer: ServerSocket? = null

            fun send(message: String) {
                writer.print("$message\r\n")
                writer.flush()
            }

            send("220 lut-shop Android FTP receiver ready")

            while (!control.isClosed) {
                val line = reader.readLine() ?: break
                val command = line.substringBefore(" ").uppercase(Locale.US)
                val argument = line.substringAfter(" ", "")

                when (command) {
                    "USER" -> send(if (argument == configuration.username) "331 Password required" else "530 Invalid username")
                    "PASS" -> {
                        authenticated = argument == configuration.password
                        send(if (authenticated) "230 Login successful" else "530 Invalid password")
                    }
                    "SYST" -> send("215 UNIX Type: L8")
                    "FEAT" -> send("211-Features\r\n EPSV\r\n PASV\r\n UTF8\r\n211 End")
                    "PWD", "XPWD" -> send("257 \"/\" is the current directory")
                    "CWD", "CDUP" -> send("250 Directory changed")
                    "TYPE" -> send("200 Type set")
                    "MODE" -> send("200 Mode set")
                    "STRU" -> send("200 Structure set")
                    "OPTS" -> send("200 OK")
                    "NOOP" -> send("200 OK")
                    "PASV" -> {
                        passiveServer?.close()
                        val server = ServerSocket(0)
                        passiveServer = server
                        val port = server.localPort
                        val bytes = localIPv4Address().split(".").mapNotNull { it.toIntOrNull() }
                        val address = if (bytes.size == 4) bytes else listOf(127, 0, 0, 1)
                        send("227 Entering Passive Mode (${address[0]},${address[1]},${address[2]},${address[3]},${port / 256},${port % 256})")
                    }
                    "EPSV" -> {
                        passiveServer?.close()
                        val server = ServerSocket(0)
                        passiveServer = server
                        send("229 Entering Extended Passive Mode (|||${server.localPort}|)")
                    }
                    "STOR" -> {
                        if (!authenticated) {
                            send("530 Login required")
                        } else {
                            val server = passiveServer
                            if (server == null) {
                                send("425 Use PASV or EPSV first")
                            } else {
                                val fileName = sanitizedFileName(argument)
                                onTransferStarted(fileName)
                                send("150 Opening data connection")
                                receiveFile(server, fileName)
                                passiveServer = null
                                send("226 Transfer complete")
                            }
                        }
                    }
                    "QUIT" -> {
                        send("221 Bye")
                        break
                    }
                    else -> send("502 Command not implemented")
                }
            }
            passiveServer?.close()
        }
    }

    private fun receiveFile(server: ServerSocket, fileName: String) {
        val target = makeInboxFile(fileName)
        server.use {
            it.accept().use { dataSocket ->
                dataSocket.getInputStream().use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                }
            }
        }
        onFileReceived(CameraReceivedFile(target, fileName))
    }

    private fun makeInboxFile(fileName: String): File {
        val directory = File(context.filesDir, "CameraReceiveInbox").apply { mkdirs() }
        return File(directory, "${System.currentTimeMillis()}-$fileName")
    }

    private fun sanitizedFileName(rawName: String): String {
        val candidate = rawName.substringAfterLast('/').substringAfterLast('\\').ifBlank { "camera-upload" }
        val sanitized = candidate.map { char ->
            if (char.isLetterOrDigit() || char == '-' || char == '_' || char == '.') char else '-'
        }.joinToString("").trim('-', '_', '.')
        return sanitized.ifBlank { "camera-upload" }
    }

    companion object {
        fun localIPv4Address(): String {
            return NetworkInterface.getNetworkInterfaces().toList()
                .flatMap { it.inetAddresses.toList() }
                .firstOrNull { address ->
                    !address.isLoopbackAddress && address is Inet4Address
                }
                ?.hostAddress
                ?: "0.0.0.0"
        }
    }
}

data class FtpReceiverConfiguration(
    val host: String,
    val port: Int = 2121,
    val username: String = "lee",
    val password: String = "123456"
)

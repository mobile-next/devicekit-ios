import Foundation
import Network

/// A lightweight TCP server built on Apple's Network.framework.
///
/// `TCPServer` listens on a specified TCP port, accepts inbound TCP connections,
/// and exposes a simple callback (`dataHandler`) for sending data back to the
/// connected client. The server uses dedicated dispatch queues for listener
/// and connection events to ensure predictable, thread‑safe behavior.
///
/// ## Important Notes
/// - Only the **most recent connection** receives data via `dataHandler`.
/// - The server does **not** read inbound data from clients. It only sends.
/// - The server does **not** retain multiple connections.
/// - The server does **not** handle connection cancellation or cleanup.
/// - The server does **not** detect client disconnects.
///
/// These are not bugs, but design constraints worth knowing.
public final class TCPServer {

    /// Errors thrown by `TCPServer`.
    enum ServerError: Error {
        /// The provided port number could not be converted into `NWEndpoint.Port`.
        case invalidPortNumber
    }

    /// Queue used for listener lifecycle events.
    private lazy var listeningQueue = DispatchQueue(label: "tcp.server.queue")

    /// Queue used for per‑connection events and data transmission.
    private lazy var connectionQueue = DispatchQueue(label: "tcp.connection.queue")

    /// The underlying Network.framework listener.
    private var listener: NWListener?

    /// A callback invoked when the server is ready to send data back to the client.
    ///
    /// This closure is set when a connection reaches `.ready`.
    /// Only the most recent connection will receive data via this handler.
    ///
    /// ## Potential Issue
    /// If multiple clients connect, earlier ones will silently stop receiving data.
    public var dataHandler: ((Data) -> Void)?

    /// Creates a new TCP server instance.
    public init() {}

    /// Starts the TCP server on the specified port.
    ///
    /// - Parameter port: The TCP port to listen on.
    /// - Throws: `ServerError.invalidPortNumber` if the port is outside the valid range.
    ///
    /// This method:
    /// 1. Cancels any existing listener.
    /// 2. Validates the port.
    /// 3. Creates a new `NWListener`.
    /// 4. Registers state and connection handlers.
    /// 5. Starts the listener on `listeningQueue`.
    ///
    /// ## Potential Issues
    /// - The server does not handle `.failed` or `.cancelled` listener states.
    /// - The server does not retry or restart on failure.
    /// - The server does not expose connection lifecycle events.
    public func start(port: UInt16) throws {
        listener?.cancel()

        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw ServerError.invalidPortNumber
        }

        listener = try NWListener(using: .tcp, on: port)

        listener?.stateUpdateHandler = { state in
            if state == .ready {
                print("listener is ready to recieve data")
            }
            // Potential improvement: handle .failed, .cancelled, .waiting
        }

        listener?.newConnectionHandler = { [weak self] connection in
            guard let weakSelf = self else { return }

            print("connection requested --> \(connection.endpoint)")

            connection.stateUpdateHandler = { state in
                if state == .ready {
                    // Assign a handler that sends data back to this connection.
                    weakSelf.dataHandler = { data in
                        weakSelf.send(data: data, on: connection)
                    }
                }

                // Potential improvement:
                // Handle .failed, .cancelled, .waiting to clean up or notify.
            }

            // ⚠️ Potential Issue:
            // No receive loop is implemented. The server cannot read inbound data.
            // If this is intentional, ignore. Otherwise, add connection.receive(...)
            connection.start(queue: weakSelf.connectionQueue)
        }

        listener?.start(queue: listeningQueue)
    }

    /// Stops the TCP server and clears all handlers.
    ///
    /// This cancels the listener, removes references, and resets the data handler.
    ///
    /// ## Potential Issue
    /// - Active connections are not cancelled.
    /// - If a connection is still alive, it may continue to exist until timeout.
    public func stop() {
        listener?.cancel()
        listener = nil
        dataHandler = nil
    }

    /// Sends data to the specified connection.
    ///
    /// - Parameters:
    ///   - data: The raw bytes to send.
    ///   - connection: The active `NWConnection` to write to.
    ///
    /// Errors are printed but not escalated.
    ///
    /// ## Potential Issue
    /// - If the connection is closed, `send` may silently fail.
    /// - No retry or backpressure handling is implemented.
    private func send(data: Data, on connection: NWConnection) {
        connection.send(
            content: data,
            completion: .contentProcessed { error in
                if let error = error {
                    print(error)
                }
            }
        )
    }
}


import Foundation
import Network

public final class TCPServer {

    enum ServerError: Error {
        case invalidPortNumber
    }

    private lazy var listeningQueue = DispatchQueue(label: "tcp.server.queue")
    private lazy var connectionQueue = DispatchQueue(label: "tcp.connection.queue")

    private var listener: NWListener?

    public var dataHandler: ((Data) -> Void)?
    public var messageHandler: ((Data) -> Void)?
    public var onClientConnected: (() -> Void)?

    public init() {}

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
        }

        listener?.newConnectionHandler = { [weak self] connection in
            guard let weakSelf = self else { return }

            print("connection requested --> \(connection.endpoint)")

            connection.stateUpdateHandler = { state in
                if state == .ready {
                    weakSelf.dataHandler = { data in
                        weakSelf.send(data: data, on: connection)
                    }

                    weakSelf.startReceiving(on: connection)

                    weakSelf.onClientConnected?()
                }
            }

            connection.start(queue: weakSelf.connectionQueue)
        }

        listener?.start(queue: listeningQueue)
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        dataHandler = nil
        messageHandler = nil
        onClientConnected = nil
    }

    private func startReceiving(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                print("[TCPServer] Receive error: \(error)")
                return
            }

            if let data = data, !data.isEmpty {
                self.messageHandler?(data)
            }

            if !isComplete {
                self.startReceiving(on: connection)
            }
        }
    }

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


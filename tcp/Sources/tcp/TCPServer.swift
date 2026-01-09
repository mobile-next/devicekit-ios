//
//  TCPServer.swift
//  ScreenStreamerServer
//
//  Created by Victor Kachalov on 22.11.23.
//

import Foundation
import Network

public final class TCPServer {

    enum ServerError: Error {
        case invalidPortNumber
    }

    private lazy var listeningQueue = DispatchQueue.init(label: "tcp.server.queue")
    private lazy var connectionQueue = DispatchQueue.init(label: "tcp.connection.queue")

    private var listener: NWListener?

    public var dataHandler: ((Data) -> Void)?

    public init() {}

    public func start(port: UInt16) throws {
        listener?.cancel()

        guard let port = NWEndpoint.Port.init(rawValue: port) else {
            throw ServerError.invalidPortNumber
        }

        listener = try NWListener.init(using: .tcp, on: port)

        listener?.stateUpdateHandler = { state in
            if state == .ready {
                print("listener is ready to recieve data")
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            guard let weakSelf = self else {
                return
            }
            print("connection requested --> \(connection.endpoint)")

            connection.stateUpdateHandler = { state in
                if state == .ready {
                    weakSelf.dataHandler = { data in
                        weakSelf.send(data: data, on: connection)
                    }
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

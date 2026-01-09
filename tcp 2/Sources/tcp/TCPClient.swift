import Foundation
import Network

/// Abstract: TCP server that can listen to port and accept connection,
/// receive data
///
/// Caution: This server can accept only one connection
public final class TCPClient {

    enum ConnectionError: Error {
        case invalidIPAdress
        case invalidPort
    }

    private lazy var queue = DispatchQueue(label: "tcp.client.queue")

    private var connection: NWConnection?

    public var recievedDataHandling: ((Data) -> Void)?

    public init() {}

    public func start(ipAddress: String, port: UInt16) throws {
        guard let ipAddress = IPv4Address(ipAddress) else {
            throw ConnectionError.invalidIPAdress
        }
        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw ConnectionError.invalidPort
        }
        let host = NWEndpoint.Host.ipv4(ipAddress)

        connection = NWConnection(host: host, port: port, using: .tcp)

        connection?.stateUpdateHandler = { [unowned self] state in
            if state == .ready {
                recieveData(on: connection)
            }
        }

        connection?.start(queue: queue)
    }

    /// receive data recursively on the connection
    private func recieveData(on connection: NWConnection?) {
        guard let connection = connection else { return }

        if connection.state != .ready {
            return
        }
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65000) {
            [unowned self] data, _, _, error in
            if let error = error {
                print(error)
            }

            if let data = data {
                recievedDataHandling?(data)
            }

            recieveData(on: connection)
        }
    }
}

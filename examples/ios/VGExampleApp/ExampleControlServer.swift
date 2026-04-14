import Foundation
import Network

final class ExampleControlServer {
    typealias Handler = (_ request: ControlRequest, _ completion: @escaping (ControlResponse) -> Void) -> Void

    private let port: NWEndpoint.Port
    private let queue = DispatchQueue(label: "com.vibegrowth.example.control-server")
    private var listener: NWListener?
    private var handler: Handler?

    init(port: UInt16) {
        self.port = NWEndpoint.Port(rawValue: port)!
    }

    func start(handler: @escaping Handler, completion: @escaping (Result<Void, Error>) -> Void) {
        if listener != nil {
            completion(.success(()))
            return
        }

        self.handler = handler

        do {
            let listener = try NWListener(using: .tcp, on: port)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    completion(.success(()))
                case .failed(let error):
                    completion(.failure(error))
                default:
                    break
                }
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            completion(.failure(error))
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, _, error in
            guard let self else {
                connection.cancel()
                return
            }
            if let error {
                self.send(ControlResponse(statusCode: 500, body: ["ok": false, "error": error.localizedDescription]), on: connection)
                return
            }
            guard
                let data,
                let rawRequest = String(data: data, encoding: .utf8),
                let request = ControlRequest.parse(rawRequest)
            else {
                self.send(ControlResponse(statusCode: 400, body: ["ok": false, "error": "Invalid HTTP request"]), on: connection)
                return
            }

            if request.path == "/health" {
                self.send(ControlResponse(statusCode: 200, body: ["ok": true]), on: connection)
                return
            }

            guard let handler = self.handler else {
                self.send(ControlResponse(statusCode: 503, body: ["ok": false, "error": "Control handler is not ready"]), on: connection)
                return
            }

            handler(request) { response in
                self.send(response, on: connection)
            }
        }
    }

    private func send(_ response: ControlResponse, on connection: NWConnection) {
        let bodyData = (try? JSONSerialization.data(withJSONObject: response.body, options: [.sortedKeys])) ?? Data("{}".utf8)
        let reason = response.statusCode == 200 ? "OK" : "Error"
        var headers = "HTTP/1.1 \(response.statusCode) \(reason)\r\n"
        headers += "Content-Type: application/json\r\n"
        headers += "Cache-Control: no-store\r\n"
        headers += "Content-Length: \(bodyData.count)\r\n"
        headers += "Connection: close\r\n"
        headers += "\r\n"

        var payload = Data(headers.utf8)
        payload.append(bodyData)
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

struct ControlRequest {
    let path: String
    let command: String
    let params: [String: String]
    let rawUrl: String

    static func parse(_ rawRequest: String) -> ControlRequest? {
        guard let requestLine = rawRequest.components(separatedBy: "\r\n").first else {
            return nil
        }
        let pieces = requestLine.split(separator: " ")
        guard pieces.count >= 2 else {
            return nil
        }

        let rawUrl = String(pieces[1])
        let components = URLComponents(string: rawUrl)
        let path = components?.path ?? rawUrl
        let command = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let params = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        return ControlRequest(path: path, command: command, params: params, rawUrl: rawUrl)
    }
}

struct ControlResponse {
    let statusCode: Int
    let body: [String: Any]
}

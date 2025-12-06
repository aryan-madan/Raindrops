
import Vapor
import Foundation

actor FileEvents {
    private var streams: [UUID: AsyncStream<Void>.Continuation] = [:]
    
    func stream() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let id = UUID()
            streams[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.remove(id) }
            }
        }
    }
    
    func remove(_ id: UUID) {
        streams[id] = nil
    }
    
    func signal() {
        for (_, continuation) in streams {
            continuation.yield()
        }
    }
}

final class Host: @unchecked Sendable {
    var app: Application!
    let port: Int
    let onStatus: @Sendable (Bool) -> Void
    let onRefresh: @Sendable () -> Void
    let pinProvider: @Sendable () async -> String
    let events: FileEvents
    
    init(port: Int, 
         onStatus: @escaping @Sendable (Bool) -> Void, 
         onRefresh: @escaping @Sendable () -> Void,
         pinProvider: @escaping @Sendable () async -> String,
         events: FileEvents) {
        self.port = port
        self.onStatus = onStatus
        self.onRefresh = onRefresh
        self.pinProvider = pinProvider
        self.events = events
    }
    
    func launch() async throws {
        app = try await Application.make(.production)
        app.http.server.configuration.hostname = "0.0.0.0"
        app.http.server.configuration.port = port
        app.http.server.configuration.responseCompression = .enabled
        app.routes.defaultMaxBodySize = "100GB"
        
        configure()
        
        try await app.execute()
    }
    
    func configure() {
        app.middleware.use(AuthMiddleware(host: self))
        
        app.get { req -> Response in
            guard let url = Bundle.module.url(forResource: "index", withExtension: "html"),
                  let html = try? String(contentsOf: url, encoding: .utf8) else {
                return Response(status: .internalServerError, body: .init(string: "Error loading UI."))
            }
            return Response(status: .ok, headers: ["Content-Type": "text/html"], body: .init(string: html))
        }

        app.get("events") { req -> Response in
            let response = Response(status: .ok, headers: [
                "Content-Type": "text/event-stream",
                "Cache-Control": "no-cache",
                "Connection": "keep-alive"
            ])
            response.body = .init(stream: { writer in
                Task {
                    let stream = await self.events.stream()
                    for await _ in stream {
                        do {
                            try await writer.write(.buffer(ByteBuffer(string: "data: update\n\n"))).get()
                        } catch {
                            break
                        }
                    }
                }
            })
            return response
        }
        
        app.post("login") { req async throws -> Response in
            struct LoginRequest: Content {
                var pin: String
            }
            
            let pinInput: String
            if let form = try? req.content.decode(LoginRequest.self) {
                pinInput = form.pin
            } else if let p = req.body.string {
                pinInput = p.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                throw Abort(.badRequest)
            }
            
            let currentPin = await self.pinProvider()
            
            if pinInput == currentPin {
                let response = Response(status: .seeOther)
                response.headers.replaceOrAdd(name: .location, value: "/")
                response.cookies["raindrops-auth"] = .init(string: currentPin, isHTTPOnly: true, sameSite: .lax)
                return response
            } else {
                return self.loginResponse(error: true)
            }
        }
        
        app.get("logo") { req -> Response in
            guard let url = Bundle.module.url(forResource: "Logo", withExtension: "svg"),
                  let data = try? Data(contentsOf: url),
                  var svg = String(data: data, encoding: .utf8) else {
                throw Abort(.notFound)
            }
            
            let style = "<style>path,circle,rect,polygon,ellipse{fill:#00cbff !important;}</style>"
            if !svg.contains("</svg>") {
                 svg += style
            } else {
                 svg = svg.replacingOccurrences(of: "</svg>", with: "\(style)</svg>")
            }
            
            return Response(status: .ok, headers: ["Content-Type": "image/svg+xml"], body: .init(string: svg))
        }
        
        app.on(.POST, "upload", body: .stream) { req async throws -> String in
            self.onStatus(true)
            let name = req.query[String.self, at: "name"] ?? "unknown_file"
            
            if name.contains("..") { throw Abort(.forbidden) }
            
            let fileURL = Storage.location.appendingPathComponent(name)
            let directory = fileURL.deletingLastPathComponent()
            
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            
            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
            guard let handle = FileHandle(forWritingAtPath: fileURL.path) else { throw Abort(.internalServerError) }
            
            do {
                for try await buffer in req.body {
                    handle.write(Data(buffer.readableBytesView))
                }
                handle.closeFile()
            } catch {
                handle.closeFile()
                self.onStatus(false)
                throw error
            }
            self.onStatus(false)
            self.onRefresh()
            await self.events.signal()
            return "OK"
        }
        
        app.get("files", ":name") { req async throws -> Response in
            guard let name = req.parameters.get("name") else { throw Abort(.badRequest) }
            let url = Storage.location.appendingPathComponent(name)
            return try await req.fileio.asyncStreamFile(at: url.path)
        }
        
        app.get("list") { req -> [String] in
            let urls = try FileManager.default.contentsOfDirectory(at: Storage.location, includingPropertiesForKeys: nil)
            return urls.map { $0.lastPathComponent }.filter { !$0.hasPrefix(".") }.sorted()
        }
    }
    
    func loginResponse(error: Bool = false) -> Response {
        guard let url = Bundle.module.url(forResource: "login", withExtension: "html"),
              var html = try? String(contentsOf: url, encoding: .utf8) else {
            return Response(status: .internalServerError, body: .init(string: "Error loading login UI."))
        }
        
        html = html.replacingOccurrences(of: "{{ERROR}}", with: error ? "Incorrect PIN" : "")
        
        return Response(status: error ? .unauthorized : .ok, headers: ["Content-Type": "text/html"], body: .init(string: html))
    }
}

struct AuthMiddleware: AsyncMiddleware {
    let host: Host
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let path = request.url.path
        if path == "/logo" || path == "/login" || path == "/events" {
            return try await next.respond(to: request)
        }
        
        let validPin = await host.pinProvider()
        
        if let cookie = request.cookies["raindrops-auth"], cookie.string == validPin {
            return try await next.respond(to: request)
        }
        
        return host.loginResponse()
    }
}

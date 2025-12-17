

import Vapor
import Foundation

struct FileItem: Content {
    let name: String
    let type: String
    let size: String
}

struct PermissionsResponse: Content {
    let read: Bool
    let write: Bool
}

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
    let readProvider: @Sendable () async -> Bool
    let writeProvider: @Sendable () async -> Bool
    let events: FileEvents
    
    init(port: Int, 
         onStatus: @escaping @Sendable (Bool) -> Void, 
         onRefresh: @escaping @Sendable () -> Void,
         pinProvider: @escaping @Sendable () async -> String,
         readProvider: @escaping @Sendable () async -> Bool,
         writeProvider: @escaping @Sendable () async -> Bool,
         events: FileEvents) {
        self.port = port
        self.onStatus = onStatus
        self.onRefresh = onRefresh
        self.pinProvider = pinProvider
        self.readProvider = readProvider
        self.writeProvider = writeProvider
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
    
    private func findResource(_ name: String, ext: String, sub: String?) -> URL? {
        if let sub = sub, let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: sub) {
            return url
        }
        if let sub = sub, let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources/\(sub)") {
            return url
        }
        return Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources") 
            ?? Bundle.module.url(forResource: name, withExtension: ext, subdirectory: nil)
    }
    
    func configure() {
        app.middleware.use(AuthMiddleware(host: self))
        
        app.get { req -> Response in
            guard let url = self.findResource("index", ext: "html", sub: "Web"),
                  let html = try? String(contentsOf: url, encoding: .utf8) else {
                return Response(status: .internalServerError, body: .init(string: "Error loading UI."))
            }
            return Response(status: .ok, headers: ["Content-Type": "text/html"], body: .init(string: html))
        }

        app.get("style.css") { req -> Response in
            guard let url = self.findResource("style", ext: "css", sub: "Web"),
                  let css = try? String(contentsOf: url, encoding: .utf8) else {
                throw Abort(.notFound)
            }
            return Response(status: .ok, headers: ["Content-Type": "text/css"], body: .init(string: css))
        }

        app.get("app.js") { req -> Response in
            guard let url = self.findResource("app", ext: "js", sub: "Web"),
                  let js = try? String(contentsOf: url, encoding: .utf8) else {
                throw Abort(.notFound)
            }
            return Response(status: .ok, headers: ["Content-Type": "application/javascript"], body: .init(string: js))
        }
        
        app.get("permissions") { req async -> PermissionsResponse in
            return PermissionsResponse(
                read: await self.readProvider(),
                write: await self.writeProvider()
            )
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
                    _ = try? await writer.write(.end).get()
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
            guard let url = self.findResource("Logo", ext: "svg", sub: nil),
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
            if await !self.writeProvider() { throw Abort(.forbidden) }
            
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
        
        app.get("files", "**") { req async throws -> Response in
            if await !self.readProvider() { throw Abort(.forbidden) }
            
            let path = req.parameters.getCatchall().joined(separator: "/")
            if path.contains("..") { throw Abort(.forbidden) }
            let url = Storage.location.appendingPathComponent(path)
            
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                process.arguments = ["-r", "-", url.lastPathComponent]
                process.currentDirectoryURL = url.deletingLastPathComponent()
                process.environment = ["PATH": "/usr/bin:/bin"]
                
                let pipe = Pipe()
                process.standardOutput = pipe
                
                let nullPipe = Pipe()
                process.standardError = nullPipe
                
                do {
                    try process.run()
                } catch {
                    throw Abort(.internalServerError, reason: "Failed to create zip archive")
                }
                
                let response = Response(status: .ok, headers: [
                    "Content-Type": "application/zip",
                    "Content-Disposition": "attachment; filename=\"\(url.lastPathComponent).zip\""
                ])
                
                response.body = .init(stream: { writer in
                    let handle = pipe.fileHandleForReading
                    handle.readabilityHandler = { h in
                        let data = h.availableData
                        if data.isEmpty {
                            h.readabilityHandler = nil
                        } else {
                            _ = writer.write(.buffer(ByteBuffer(data: data)))
                        }
                    }
                    
                    process.terminationHandler = { _ in
                        handle.readabilityHandler = nil
                        _ = writer.write(.end)
                    }
                })
                return response
            }
            
            return try await req.fileio.asyncStreamFile(at: url.path)
        }
        
        app.get("list") { req -> [FileItem] in
            if await !self.readProvider() { throw Abort(.forbidden) }
            
            let path = req.query[String.self, at: "path"] ?? ""
            if path.contains("..") { throw Abort(.forbidden) }
            
            let root = Storage.location
            let url = path.isEmpty ? root : root.appendingPathComponent(path)
            
            if !url.path.hasPrefix(root.path) {
                throw Abort(.forbidden)
            }
            
            guard let urls = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]) else {
                return []
            }
            
            return urls.compactMap { url -> FileItem? in
                let name = url.lastPathComponent
                if name.hasPrefix(".") { return nil }
                
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                let type = isDir.boolValue ? "folder" : "file"
                
                var size: Int64 = 0
                if !isDir.boolValue {
                    let attr = try? FileManager.default.attributesOfItem(atPath: url.path)
                    size = (attr?[.size] as? Int64) ?? 0
                }
                
                return FileItem(
                    name: name,
                    type: type,
                    size: isDir.boolValue ? "--" : ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                )
            }.sorted { 
                if $0.type == $1.type {
                     return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.type == "folder"
            }
        }
    }
    
    func loginResponse(error: Bool = false) -> Response {
        guard let url = self.findResource("login", ext: "html", sub: "Web"),
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
        if path == "/logo" || path == "/login" || path == "/events" || path == "/style.css" || path == "/app.js" {
            return try await next.respond(to: request)
        }
        
        let validPin = await host.pinProvider()
        
        if let cookie = request.cookies["raindrops-auth"], cookie.string == validPin {
            return try await next.respond(to: request)
        }
        
        return host.loginResponse()
    }
}


import Vapor
import Foundation

final class Host: @unchecked Sendable {
    var app: Application!
    let port: Int
    let onStatus: @Sendable (Bool) -> Void
    let onRefresh: @Sendable () -> Void
    
    init(port: Int, onStatus: @escaping @Sendable (Bool) -> Void, onRefresh: @escaping @Sendable () -> Void) {
        self.port = port
        self.onStatus = onStatus
        self.onRefresh = onRefresh
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
        app.get { req -> Response in
            guard let url = Bundle.module.url(forResource: "index", withExtension: "html"),
                  let html = try? String(contentsOf: url, encoding: .utf8) else {
                return Response(status: .internalServerError, body: .init(string: "Error loading UI."))
            }
            return Response(status: .ok, headers: ["Content-Type": "text/html"], body: .init(string: html))
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
}

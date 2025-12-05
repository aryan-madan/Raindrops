
import Vapor
import Foundation

final class Host: @unchecked Sendable {
    var app: Application!
    let port: Int
    let onStatus: @Sendable (Bool) -> Void
    let onRefresh: @Sendable () -> Void
    let pinProvider: @Sendable () async -> String
    
    init(port: Int, 
         onStatus: @escaping @Sendable (Bool) -> Void, 
         onRefresh: @escaping @Sendable () -> Void,
         pinProvider: @escaping @Sendable () async -> String) {
        self.port = port
        self.onStatus = onStatus
        self.onRefresh = onRefresh
        self.pinProvider = pinProvider
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
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Raindrops Access</title>
            <style>
                :root {
                    --bg: #050505;
                    --input-bg: #111;
                    --border: #222;
                    --accent: #00cbff;
                    --text: #fff;
                    --text-sec: #666;
                }
                body {
                    margin: 0;
                    height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    background: var(--bg);
                    color: var(--text);
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                }
                .container {
                    width: 100%;
                    max-width: 320px;
                    padding: 20px;
                    text-align: center;
                }
                .logo {
                    width: 48px;
                    height: 48px;
                    margin-bottom: 32px;
                }
                h1 {
                    font-size: 20px;
                    font-weight: 600;
                    margin: 0 0 8px 0;
                }
                p {
                    font-size: 14px;
                    color: var(--text-sec);
                    margin: 0 0 32px 0;
                }
                form {
                    display: flex;
                    flex-direction: column;
                    gap: 16px;
                }
                input {
                    background: var(--input-bg);
                    border: 1px solid var(--border);
                    border-radius: 8px;
                    padding: 12px;
                    font-size: 16px;
                    color: var(--text);
                    text-align: center;
                    outline: none;
                    transition: all 0.2s;
                    font-family: inherit;
                }
                input:focus {
                    border-color: var(--accent);
                    background: #151515;
                }
                button {
                    background: var(--text);
                    color: var(--bg);
                    border: none;
                    padding: 12px;
                    border-radius: 8px;
                    font-size: 14px;
                    font-weight: 600;
                    cursor: pointer;
                    transition: opacity 0.2s;
                }
                button:hover {
                    opacity: 0.9;
                }
                .error {
                    color: #ff453a;
                    font-size: 13px;
                    height: 20px;
                    margin-top: -8px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <img src="/logo" class="logo" alt="Raindrops">
                <h1>Private Session</h1>
                <p>Enter the 4-digit PIN to connect</p>
                <form method="POST" action="/login">
                    <input type="text" name="pin" placeholder="PIN" maxlength="4" inputmode="numeric" pattern="[0-9]*" autocomplete="off" autofocus required>
                    <div class="error">\(error ? "Incorrect PIN" : "")</div>
                    <button type="submit">Access Files</button>
                </form>
            </div>
        </body>
        </html>
        """
        return Response(status: error ? .unauthorized : .ok, headers: ["Content-Type": "text/html"], body: .init(string: html))
    }
}

struct AuthMiddleware: AsyncMiddleware {
    let host: Host
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let path = request.url.path
        if path == "/logo" || path == "/login" {
            return try await next.respond(to: request)
        }
        
        let validPin = await host.pinProvider()
        
        if let cookie = request.cookies["raindrops-auth"], cookie.string == validPin {
            return try await next.respond(to: request)
        }
        
        return host.loginResponse()
    }
}

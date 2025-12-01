
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
        app.get { req in
            return Response(status: .ok, headers: ["Content-Type": "text/html"], body: .init(string: self.html))
        }
        
        app.on(.POST, "upload", body: .stream) { req async throws -> String in
            self.onStatus(true)
            let name = req.query[String.self, at: "name"] ?? "unknown_file"
            let path = Storage.location.appendingPathComponent(name).path
            FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
            guard let handle = FileHandle(forWritingAtPath: path) else { throw Abort(.internalServerError) }
            
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
    
    var html: String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Raindrops</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    max-width: 500px;
                    margin: 0 auto;
                    padding: 40px 20px;
                    color: #111;
                    line-height: 1.5;
                    -webkit-font-smoothing: antialiased;
                }
                h1 {
                    font-size: 24px;
                    font-weight: 600;
                    margin-bottom: 40px;
                    letter-spacing: -0.5px;
                }
                .upload-zone {
                    border: 1px dashed #ccc;
                    border-radius: 8px;
                    padding: 40px;
                    text-align: center;
                    cursor: pointer;
                    margin-bottom: 40px;
                    transition: border-color 0.2s;
                    color: #666;
                    font-size: 14px;
                }
                .upload-zone:hover {
                    border-color: #000;
                    color: #000;
                }
                .file-list {
                    border-top: 1px solid #eee;
                }
                .file-item {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding: 16px 0;
                    border-bottom: 1px solid #eee;
                    text-decoration: none;
                    color: #111;
                    font-size: 15px;
                }
                .file-item:hover {
                    color: #666;
                }
                .download-icon {
                    color: #999;
                    font-size: 14px;
                }
                .empty-state {
                    padding: 20px 0;
                    color: #999;
                    font-size: 14px;
                }
                #progress-bar {
                    display: none;
                    margin-bottom: 30px;
                    font-size: 13px;
                    color: #666;
                }
            </style>
        </head>
        <body>
            <h1>Raindrops</h1>

            <div class="upload-zone" onclick="document.getElementById('file-input').click()">
                Select or drop file
            </div>
            <input type="file" id="file-input" hidden onchange="uploadFile(this)">

            <div id="progress-bar">Uploading... <span id="progress-text">0%</span></div>
            
            <div id="file-list" class="file-list"></div>

            <script>
                async function uploadFile(el) {
                    let file = el.files[0];
                    if(!file) return;
                    
                    let bar = document.getElementById('progress-bar');
                    let txt = document.getElementById('progress-text');
                    bar.style.display = 'block';
                    
                    let xhr = new XMLHttpRequest();
                    xhr.open('POST', '/upload?name=' + encodeURIComponent(file.name), true);
                    
                    xhr.upload.onprogress = (e) => {
                        if (e.lengthComputable) {
                            txt.innerText = Math.round((e.loaded / e.total) * 100) + '%';
                        }
                    };
                    
                    xhr.onload = () => {
                        bar.style.display = 'none';
                        el.value = '';
                        loadFiles();
                    };
                    
                    xhr.send(file);
                }
                
                async function loadFiles() {
                    let container = document.getElementById('file-list');
                    try {
                        let res = await fetch('/list');
                        let files = await res.json();
                        
                        if(files.length === 0) {
                            container.innerHTML = '<div class="empty-state">No files shared</div>';
                            return;
                        }
                        
                        container.innerHTML = files.map(f => `
                            <a href="/files/${encodeURIComponent(f)}" class="file-item" download>
                                <span>${f}</span>
                                <span class="download-icon">↓</span>
                            </a>
                        `).join('');
                    } catch {
                        container.innerHTML = '<div class="empty-state">Disconnected</div>';
                    }
                }
                
                loadFiles();
            </script>
        </body>
        </html>
        """
    }
}

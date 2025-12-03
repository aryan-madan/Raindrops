

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
    
    var html: String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>Raindrops</title>
            <script src="https://unpkg.com/@phosphor-icons/web"></script>
            <style>
                :root {
                    --bg: #ffffff;
                    --panel: #f8f8f8;
                    --border: #e6e6e6;
                    --text: #111111;
                    --text-sec: #777777;
                    --accent: #000000;
                    --on-accent: #ffffff;
                    --radius: 12px;
                }

                @media (prefers-color-scheme: dark) {
                    :root {
                        --bg: #0a0a0a;
                        --panel: #161616;
                        --border: #262626;
                        --text: #f0f0f0;
                        --text-sec: #888888;
                        --accent: #ffffff;
                        --on-accent: #000000;
                    }
                }

                * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; outline: none; }
                
                body {
                    margin: 0; padding: 0;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    background: var(--bg);
                    color: var(--text);
                    height: 100vh;
                    display: flex;
                    overflow: hidden;
                    font-size: 14px;
                }

                a { text-decoration: none; color: inherit; }
                button { font-family: inherit; }

                aside {
                    width: 240px;
                    border-right: 1px solid var(--border);
                    display: flex;
                    flex-direction: column;
                    padding: 24px;
                    background: var(--bg);
                    flex-shrink: 0;
                    z-index: 10;
                }

                .logo {
                    font-weight: 600;
                    font-size: 16px;
                    display: flex; align-items: center; gap: 8px;
                    margin-bottom: 32px;
                    color: var(--text);
                    opacity: 0.9;
                }
                .logo i { font-size: 20px; }

                .btn-primary {
                    background: var(--accent);
                    color: var(--on-accent);
                    border: none;
                    padding: 12px;
                    border-radius: var(--radius);
                    font-weight: 500;
                    cursor: pointer;
                    display: flex; align-items: center; justify-content: center; gap: 8px;
                    transition: opacity 0.2s;
                    margin-bottom: 24px;
                }
                .btn-primary:hover { opacity: 0.85; }

                .nav-link {
                    display: flex; align-items: center; gap: 12px;
                    padding: 10px 12px;
                    color: var(--text-sec);
                    border-radius: 8px;
                    margin-bottom: 2px;
                    transition: 0.15s;
                }
                .nav-link:hover { color: var(--text); background: var(--panel); }
                .nav-link.active { color: var(--text); font-weight: 500; background: var(--panel); }
                .nav-link i { font-size: 18px; }

                .layout-col {
                    flex: 1;
                    display: flex;
                    flex-direction: column;
                    min-width: 0;
                    position: relative;
                }

                header {
                    padding: 16px 24px;
                    display: flex; align-items: center; justify-content: space-between;
                    border-bottom: 1px solid transparent;
                }

                .mobile-logo { display: none; font-weight: 600; align-items: center; gap: 8px; }
                
                .search-box {
                    background: var(--panel);
                    border: 1px solid transparent;
                    border-radius: 10px;
                    height: 40px;
                    display: flex; align-items: center;
                    padding: 0 12px;
                    gap: 10px;
                    width: 300px;
                    transition: 0.2s;
                }
                .search-box:focus-within { background: var(--bg); border-color: var(--border); width: 400px; }
                .search-box i { color: var(--text-sec); font-size: 16px; }
                .search-box input { border: none; background: transparent; flex: 1; color: var(--text); font-size: 14px; }
                .search-box input::placeholder { color: var(--text-sec); opacity: 0.6; }

                .list-wrap {
                    flex: 1;
                    position: relative;
                    overflow: hidden;
                    display: flex;
                    flex-direction: column;
                }
                
                .scroll-container {
                    flex: 1;
                    overflow-y: auto;
                    padding: 24px;
                    mask-image: linear-gradient(to bottom, black, black);
                    -webkit-mask-image: linear-gradient(to bottom, black, black);
                    transition: -webkit-mask-image 0.2s ease, mask-image 0.2s ease;
                }
                
                .scroll-container[data-fade="top"] {
                    mask-image: linear-gradient(to bottom, transparent, black 32px);
                    -webkit-mask-image: linear-gradient(to bottom, transparent, black 32px);
                }
                .scroll-container[data-fade="bottom"] {
                    mask-image: linear-gradient(to top, transparent, black 32px);
                    -webkit-mask-image: linear-gradient(to top, transparent, black 32px);
                }
                .scroll-container[data-fade="both"] {
                    mask-image: linear-gradient(to bottom, transparent, black 32px, black calc(100% - 32px), transparent);
                    -webkit-mask-image: linear-gradient(to bottom, transparent, black 32px, black calc(100% - 32px), transparent);
                }

                .file-row {
                    display: flex; align-items: center;
                    padding: 12px 0;
                    border-bottom: 1px solid var(--border);
                    cursor: pointer;
                    transition: opacity 0.2s;
                    group;
                }
                
                .f-thumb {
                    width: 44px; height: 44px;
                    border-radius: 8px;
                    background: var(--panel);
                    border: 1px solid var(--border);
                    display: flex; align-items: center; justify-content: center;
                    overflow: hidden;
                    flex-shrink: 0;
                    margin-right: 16px;
                }
                .f-thumb img { width: 100%; height: 100%; object-fit: cover; display: block; }
                .f-thumb i { font-size: 20px; color: var(--text-sec); }
                
                .f-info { flex: 1; min-width: 0; }
                .f-name { font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--text); }
                .f-meta { font-size: 12px; color: var(--text-sec); margin-top: 3px; }
                
                .f-action {
                    width: 38px; height: 38px;
                    border-radius: 19px;
                    display: flex; align-items: center; justify-content: center;
                    color: var(--text);
                    background: var(--bg);
                    border: 1px solid var(--border);
                    transition: all 0.2s cubic-bezier(0.2, 0.8, 0.2, 1);
                    box-shadow: 0 2px 4px rgba(0,0,0,0.02);
                    font-size: 18px;
                }
                
                @media (min-width: 769px) {
                    .f-action {
                        background: transparent;
                        border-color: transparent;
                        box-shadow: none;
                        color: var(--text-sec);
                        opacity: 0.7;
                    }
                    
                    .file-row:hover .f-action {
                        background: var(--bg);
                        border-color: var(--border);
                        opacity: 1;
                        color: var(--text);
                        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
                    }
                    
                    .f-action:hover {
                        background: var(--text) !important;
                        color: var(--bg) !important;
                        border-color: var(--text) !important;
                        transform: scale(1.05);
                        box-shadow: 0 4px 12px rgba(0,0,0,0.2) !important;
                    }
                }

                @media (max-width: 768px) {
                    .f-action {
                        background: transparent;
                        border: none;
                        box-shadow: none;
                        width: 32px; height: 32px;
                        color: var(--text-sec);
                    }
                }

                .empty {
                    height: 100%; display: flex; flex-direction: column; align-items: center; justify-content: center;
                    color: var(--text-sec); text-align: center;
                }
                .empty i { font-size: 48px; margin-bottom: 16px; opacity: 0.3; }
                .empty p { margin: 4px 0; }

                .queue-panel {
                    position: fixed; bottom: 24px; right: 24px; width: 320px;
                    background: var(--bg); border: 1px solid var(--border);
                    border-radius: 16px;
                    box-shadow: 0 8px 32px rgba(0,0,0,0.12);
                    display: none; flex-direction: column;
                    overflow: hidden; z-index: 100;
                }
                .q-header {
                    padding: 12px 16px;
                    background: var(--panel);
                    font-size: 13px; font-weight: 600;
                    display: flex; justify-content: space-between; align-items: center;
                }
                .q-list { max-height: 200px; overflow-y: auto; }
                .q-item { padding: 10px 16px; border-bottom: 1px solid var(--border); display: flex; align-items: center; gap: 10px; font-size: 13px; }
                .q-item:last-child { border-bottom: none; }
                
                @media (max-width: 768px) {
                    aside { display: none; }
                    .mobile-logo { display: flex; }
                    header { padding: 12px 20px; gap: 16px; }
                    .search-box { width: auto; flex: 1; }
                    .search-box:focus-within { width: auto; }
                    .scroll-container { padding: 0 20px 80px 20px; }
                    .queue-panel { left: 16px; right: 16px; bottom: 16px; width: auto; }
                }

                .fab-wrap {
                    position: fixed; bottom: 24px; right: 24px; z-index: 90;
                    display: none; flex-direction: column; align-items: flex-end; gap: 12px;
                }
                @media (max-width: 768px) { .fab-wrap { display: flex; } }
                
                .fab-btn {
                    width: 56px; height: 56px;
                    border-radius: 28px;
                    background: var(--text); color: var(--bg);
                    display: flex; align-items: center; justify-content: center;
                    font-size: 24px; border: none;
                    box-shadow: 0 4px 12px rgba(0,0,0,0.2);
                    transition: transform 0.2s;
                }
                .fab-btn.active { transform: rotate(45deg); }
                
                .fab-menu {
                    background: var(--bg); border: 1px solid var(--border);
                    border-radius: 12px; padding: 6px;
                    display: flex; flex-direction: column; min-width: 160px;
                    transform-origin: bottom right;
                    transform: scale(0.9); opacity: 0; pointer-events: none;
                    transition: 0.2s cubic-bezier(0.3, 0, 0, 1);
                    box-shadow: 0 4px 20px rgba(0,0,0,0.15);
                }
                .fab-menu.show { transform: scale(1); opacity: 1; pointer-events: auto; }
                .fab-item {
                    padding: 10px 12px; display: flex; align-items: center; gap: 10px;
                    border-radius: 8px; color: var(--text); font-size: 14px; cursor: pointer;
                }
                .fab-item:active { background: var(--panel); }

                .drag-cover {
                    position: fixed; inset: 0; background: rgba(0,0,0,0.5);
                    backdrop-filter: blur(4px); z-index: 999;
                    display: none; align-items: center; justify-content: center;
                    color: white; font-weight: 500; flex-direction: column; gap: 20px;
                }
                .drag-cover.active { display: flex; }
                .drag-cover i { font-size: 48px; }

                .pop-menu {
                    position: absolute; top: 70px; left: 24px;
                    background: var(--bg); border: 1px solid var(--border);
                    border-radius: 12px; padding: 6px; width: 200px;
                    box-shadow: 0 4px 16px rgba(0,0,0,0.1);
                    display: none; z-index: 100;
                }
                .pop-menu.show { display: block; animation: fade 0.1s; }
                .pop-item {
                    padding: 10px 12px; display: flex; align-items: center; gap: 10px;
                    border-radius: 6px; color: var(--text); font-size: 13px; cursor: pointer;
                }
                .pop-item:hover { background: var(--panel); }

                @keyframes fade { from { opacity:0; transform:translateY(-5px); } to { opacity:1; transform:translateY(0); } }
            </style>
        </head>
        <body>
            <aside>
                <div class="logo">
                    <i class="ph-fill ph-drop"></i> RAINDROPS
                </div>
                <button class="btn-primary" onclick="togglePop(event)">
                    <i class="ph-bold ph-plus"></i> New Upload
                </button>
                <div class="pop-menu" id="pop-menu">
                    <div class="pop-item" onclick="pick('file')"><i class="ph ph-file-plus"></i> Upload Files</div>
                    <div class="pop-item" onclick="pick('folder')"><i class="ph ph-folder-plus"></i> Upload Folder</div>
                </div>

                <a href="#" class="nav-link active"><i class="ph ph-files"></i> All Files</a>
            </aside>

            <div class="layout-col">
                <header>
                    <div class="mobile-logo"><i class="ph-fill ph-drop"></i></div>
                    <div class="search-box">
                        <i class="ph ph-magnifying-glass"></i>
                        <input type="text" id="search" placeholder="Filter files..." onkeyup="filter()">
                    </div>
                </header>

                <div class="list-wrap">
                    <div class="scroll-container" id="file-list"></div>
                </div>
            </div>

            <div class="fab-wrap">
                <div class="fab-menu" id="fab-menu">
                    <div class="fab-item" onclick="pick('file')"><i class="ph ph-file-plus"></i> Upload Files</div>
                    <div class="fab-item" onclick="pick('folder')"><i class="ph ph-folder-plus"></i> Upload Folder</div>
                </div>
                <button class="fab-btn" id="fab-btn" onclick="toggleFab()">
                    <i class="ph ph-plus"></i>
                </button>
            </div>

            <input type="file" id="file-input" hidden multiple onchange="handleFiles(this.files)">
            <input type="file" id="folder-input" hidden webkitdirectory onchange="handleFiles(this.files)">

            <div class="queue-panel" id="queue">
                <div class="q-header">
                    <span id="q-status">Uploading...</span>
                    <i class="ph ph-x" onclick="document.getElementById('queue').style.display='none'" style="cursor:pointer"></i>
                </div>
                <div class="q-list" id="q-list"></div>
            </div>

            <div class="drag-cover" id="drag-overlay">
                <i class="ph ph-upload-simple"></i>
                <span>Drop files to upload</span>
            </div>

            <script>
                let all = [];
                
                const listEl = document.getElementById('file-list');
                listEl.addEventListener('scroll', updateMask);
                window.addEventListener('resize', updateMask);
                
                function updateMask() {
                    const t = listEl.scrollTop > 10;
                    const b = listEl.scrollTop + listEl.clientHeight < listEl.scrollHeight - 10;
                    let s = 'none';
                    if(t && b) s = 'both';
                    else if(t) s = 'top';
                    else if(b) s = 'bottom';
                    listEl.setAttribute('data-fade', s);
                }

                function togglePop(e) {
                    e.stopPropagation();
                    document.getElementById('pop-menu').classList.toggle('show');
                }
                
                function toggleFab() {
                    document.getElementById('fab-menu').classList.toggle('show');
                    document.getElementById('fab-btn').classList.toggle('active');
                }

                document.addEventListener('click', e => {
                    if (!e.target.closest('.pop-menu') && !e.target.closest('.btn-primary')) {
                        document.getElementById('pop-menu').classList.remove('show');
                    }
                    if (!e.target.closest('.fab-wrap')) {
                        document.getElementById('fab-menu').classList.remove('show');
                        document.getElementById('fab-btn').classList.remove('active');
                    }
                });

                function pick(t) {
                    document.getElementById(t + '-input').click();
                    document.getElementById('pop-menu').classList.remove('show');
                    document.getElementById('fab-menu').classList.remove('show');
                }

                async function load() {
                    try {
                        let r = await fetch('/list');
                        all = await r.json();
                        render(all);
                        setTimeout(updateMask, 100);
                    } catch (e) { console.log(e); }
                }

                function getIcon(n) {
                    let e = n.split('.').pop().toLowerCase();
                    if(['pdf'].includes(e)) return 'ph-file-pdf';
                    if(['zip','rar','7z'].includes(e)) return 'ph-file-archive';
                    if(['mp4','mov'].includes(e)) return 'ph-film-strip';
                    if(['mp3','wav'].includes(e)) return 'ph-music-note';
                    if(['txt','md','code','js','html','css'].includes(e)) return 'ph-file-text';
                    return 'ph-file';
                }

                function render(files) {
                    const c = document.getElementById('file-list');
                    if (!files.length) {
                        c.innerHTML = `<div class="empty"><i class="ph ph-ghost"></i><p>No files yet</p></div>`;
                        return;
                    }
                    
                    c.innerHTML = files.map(n => {
                        let ext = n.split('.').pop().toLowerCase();
                        let isImg = ['jpg','jpeg','png','gif','webp','heic'].includes(ext);
                        let preview = isImg 
                            ? `<img src="/files/${encodeURIComponent(n)}" loading="lazy">` 
                            : `<i class="ph ${getIcon(n)}"></i>`;
                        
                        return `
                        <a href="/files/${encodeURIComponent(n)}" class="file-row" download>
                            <div class="f-thumb">${preview}</div>
                            <div class="f-info">
                                <div class="f-name">${n}</div>
                                <div class="f-meta">Tap to download</div>
                            </div>
                            <div class="f-action"><i class="ph ph-download-simple"></i></div>
                        </a>`;
                    }).join('');
                    
                    setTimeout(updateMask, 50);
                }

                function filter() {
                    let q = document.getElementById('search').value.toLowerCase();
                    render(all.filter(x => x.toLowerCase().includes(q)));
                }

                let q = [], active = false;
                
                function handleFiles(files) {
                    if (!files.length) return;
                    Array.from(files).forEach(f => {
                        q.push({f, p: f.webkitRelativePath||f.name, id: Math.random().toString(36).substr(2)});
                    });
                    process();
                }

                function updateQ() {
                    let p = document.getElementById('queue');
                    let l = document.getElementById('q-list');
                    let s = document.getElementById('q-status');
                    
                    if (!q.length && !active) {
                        s.innerText = "Done";
                        setTimeout(() => p.style.display = 'none', 2000);
                        return;
                    }
                    p.style.display = 'flex';
                    s.innerText = active ? "Uploading..." : "In Queue: " + q.length;
                    
                    let show = active ? [curr] : [];
                    show = show.concat(q.slice(0,4));
                    l.innerHTML = show.map(i => `
                        <div class="q-item">
                            <i class="ph ph-spinner ph-spin"></i>
                            <div style="flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${i.p}</div>
                            <span>${i.pct||'0%'}</span>
                        </div>
                    `).join('');
                }

                let curr = null;
                async function process() {
                    if (active) return;
                    if (!q.length) { updateQ(); load(); return; }
                    
                    active = true;
                    curr = q.shift();
                    updateQ();
                    
                    try {
                        await new Promise((res, rej) => {
                            let xhr = new XMLHttpRequest();
                            xhr.open('POST', '/upload?name=' + encodeURIComponent(curr.p));
                            xhr.upload.onprogress = e => {
                                if(e.lengthComputable) {
                                    curr.pct = Math.round((e.loaded/e.total)*100) + '%';
                                    updateQ();
                                }
                            };
                            xhr.onload = () => xhr.status===200 ? res() : rej();
                            xhr.onerror = rej;
                            xhr.send(curr.f);
                        });
                    } catch(e) {}
                    
                    active = false;
                    curr = null;
                    process();
                }

                let ov = document.getElementById('drag-overlay');
                window.ondragover = e => { e.preventDefault(); ov.classList.add('active'); };
                window.ondragleave = e => { if(!e.relatedTarget) ov.classList.remove('active'); };
                window.ondrop = e => {
                    e.preventDefault(); ov.classList.remove('active');
                    let items = e.dataTransfer.items;
                    if (items) {
                        for(let i=0; i<items.length; i++) scan(items[i].webkitGetAsEntry());
                    } else handleFiles(e.dataTransfer.files);
                };

                function scan(entry, path="") {
                    if (entry.isFile) entry.file(f => {
                        q.push({f, p: path+f.name, id: Math.random().toString(36)});
                        process();
                    });
                    else if (entry.isDirectory) {
                        let r = entry.createReader();
                        r.readEntries(es => es.forEach(e => scan(e, path+entry.name+"/")));
                    }
                }

                load();
            </script>
        </body>
        </html>
        """
    }
}

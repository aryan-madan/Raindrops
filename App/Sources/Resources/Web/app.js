

let currentFiles = [];
let viewMode = localStorage.getItem('viewMode') || 'grid';
let uploadQueue = [];
let isUploading = false;
let isDraggingSeek = false;
let currentPath = "";
let permissions = { read: true, write: true };

document.addEventListener('DOMContentLoaded', () => {
    checkPermissions();
    
    new EventSource("/events").onmessage = () => {
        checkPermissions();
    };
    
    const seek = document.getElementById('mp-seek');
    if (seek) {
        seek.addEventListener('mousedown', () => isDraggingSeek = true);
        seek.addEventListener('touchstart', () => isDraggingSeek = true);
        seek.addEventListener('mouseup', () => isDraggingSeek = false);
        seek.addEventListener('touchend', () => isDraggingSeek = false);
        updateSeekFill();
    }
});

async function checkPermissions() {
    try {
        const res = await fetch('/permissions');
        if (res.ok) {
            permissions = await res.json();
        }
    } catch(e) {
        console.error("Failed to fetch permissions", e);
    }
    updateInterface();
}

function updateInterface() {
    // Write Permissions
    const uploadSection = document.getElementById('upload-section');
    const fabBtn = document.getElementById('fab-btn');
    const dragShade = document.getElementById('drag-shade');
    
    if (permissions.write) {
        if(uploadSection) uploadSection.style.display = '';
        if(fabBtn) fabBtn.style.display = '';
        setupDrag();
    } else {
        if(uploadSection) uploadSection.style.display = 'none';
        if(fabBtn) fabBtn.style.display = 'none';
        window.ondragover = null;
        window.ondrop = null;
    }

    // Read Permissions
    const searchWrap = document.querySelector('.search-wrap');
    const viewOpts = document.querySelector('.view-opts');
    const container = document.getElementById('container');
    const breadcrumbs = document.getElementById('breadcrumbs');

    if (permissions.read) {
        if(searchWrap) searchWrap.style.display = '';
        if(viewOpts) viewOpts.style.display = '';
        if(breadcrumbs) breadcrumbs.style.display = '';
        setView(viewMode);
        load();
    } else {
        if(searchWrap) searchWrap.style.display = 'none';
        if(viewOpts) viewOpts.style.display = 'none';
        if(breadcrumbs) breadcrumbs.style.display = 'none';
        
        if (container) {
            let msg = '';
            if (permissions.write) {
                msg = `
                <div class="empty" style="grid-column:1/-1;">
                    <div class="empty-icon"><i class="ph-duotone ph-cloud-arrow-up"></i></div>
                    <h3>Drop Box Mode</h3>
                    <p>You can upload files, but existing files are hidden.</p>
                </div>`;
            } else {
                msg = `
                <div class="empty" style="grid-column:1/-1;">
                    <div class="empty-icon"><i class="ph-duotone ph-lock-key"></i></div>
                    <h3>Clipboard Only</h3>
                    <p>File transfer is currently disabled by the host.</p>
                </div>`;
            }
            container.innerHTML = msg;
        }
    }
}

function setView(mode) {
    if(!permissions.read) return;
    viewMode = mode;
    localStorage.setItem('viewMode', mode);
    const el = document.getElementById('container');
    if(el) el.className = mode;
    const btnGrid = document.getElementById('btn-grid');
    const btnList = document.getElementById('btn-list');
    if(btnGrid) btnGrid.className = `view-btn ${mode === 'grid' ? 'active' : ''}`;
    if(btnList) btnList.className = `view-btn ${mode === 'list' ? 'active' : ''}`;
    render(currentFiles);
}

async function load() {
    if(!permissions.read) return;
    try {
        const res = await fetch(`/list?path=${encodeURIComponent(currentPath)}`);
        if (res.status === 403) {
            // Permissions might have changed mid-session
            permissions.read = false;
            updateInterface();
            return;
        }
        currentFiles = await res.json();
        render(currentFiles);
        updateBreadcrumbs();
    } catch (e) {}
}

function updateBreadcrumbs() {
    if(!permissions.read) return;
    const el = document.getElementById('breadcrumbs');
    if (!el) return;

    let html = `<span onclick="navigateTo('')" class="${currentPath === '' ? 'active' : ''}">Home</span>`;
    
    if (currentPath) {
        const parts = currentPath.split('/');
        let buildPath = '';
        parts.forEach((p, i) => {
            buildPath += (buildPath ? '/' : '') + p;
            html += `<i class="ph-bold ph-caret-right separator"></i>`;
            const isActive = i === parts.length - 1;
            const safePath = buildPath.replace(/'/g, "\\'");
            html += `<span onclick="navigateTo('${safePath}')" class="${isActive ? 'active' : ''}">${p}</span>`;
        });
        
        const dlUrl = `/files/${encodeURIComponent(currentPath)}`;
        html += `<a href="${dlUrl}" class="btn-dl-folder" download><i class="ph-bold ph-download-simple"></i> Download Folder</a>`;
    }
    
    el.innerHTML = html;
}

function navigateTo(path) {
    if(!permissions.read) return;
    currentPath = path;
    load();
}

function render(files) {
    if(!permissions.read) return;
    const el = document.getElementById('container');
    if(!el) return;
    
    if (!files.length) {
        el.innerHTML = `
            <div class="empty" style="grid-column:1/-1;">
                <div class="empty-icon"><i class="ph-fill ph-upload-simple"></i></div>
                <h3>No Files</h3>
                <p>Drop files here or use the upload button.</p>
            </div>`;
        return;
    }

    el.innerHTML = files.map(item => {
        const name = item.name;
        const type = item.type; 
        const size = item.size;
        
        const ext = name.split('.').pop().toLowerCase();
        const safe = name.replace(/'/g, "\\'");
    
        const fullRelPath = currentPath ? `${currentPath}/${name}` : name;
        const url = `/files/${encodeURIComponent(fullRelPath)}`;
        
        const isImg = type === 'file' && ['jpg','jpeg','png','gif','webp','svg'].includes(ext);
        
        let icon = 'ph-file';
        if (type === 'folder') icon = 'ph-folder';
        else {
            if(['pdf'].includes(ext)) icon = 'ph-file-pdf';
            if(['mp4','mov','webm'].includes(ext)) icon = 'ph-film-strip';
            if(['zip','rar'].includes(ext)) icon = 'ph-archive';
            if(['mp3','wav','ogg','m4a','flac','aac'].includes(ext)) icon = 'ph-music-note';
            if(['txt','md','json'].includes(ext)) icon = 'ph-file-text';
            if(['html','css','js','py','swift'].includes(ext)) icon = 'ph-code';
            if(['xls','xlsx','csv'].includes(ext)) icon = 'ph-file-xls';
            if(['doc','docx'].includes(ext)) icon = 'ph-file-doc';
        }

        const clickAction = type === 'folder' 
            ? `onclick="openFolder('${safe}')"` 
            : `onclick="openFile('${safe}')"`;

        if (viewMode === 'grid') {
            let preview;
            if (isImg) {
                preview = `<img src="${url}" loading="lazy" alt="${name}">`;
            } else {
                let iconClass = icon;
                if(type === 'folder') iconClass = 'ph-folder'; // Use generic folder class
                preview = `<i class="ph-duotone ${iconClass}"></i>`;
            }
            
            return `
            <div class="card" ${clickAction} title="${name}">
                <div class="card-preview">${preview}</div>
                <div class="card-info">
                    <div class="name">${name}</div>
                    <div class="ext">${type === 'folder' ? 'FOLDER' : ext.toUpperCase()}</div>
                </div>
            </div>`;
        } else {
            let preview;
            if (isImg) {
                preview = `<img src="${url}" loading="lazy" alt="icon">`;
            } else {
                let iconClass = icon;
                if(type === 'folder') iconClass = 'ph-folder';
                preview = `<i class="ph ${iconClass}"></i>`;
            }

            return `
            <div class="row" ${clickAction}>
                <div class="row-icon">${preview}</div>
                <div class="row-name">${name}</div>
                <div class="row-size">${size}</div>
            </div>`;
        }
    }).join('');
}

function openFolder(name) {
    if(!permissions.read) return;
    currentPath = currentPath ? `${currentPath}/${name}` : name;
    load();
}

function openFile(name) {
    if(!permissions.read) return;
    const ext = name.split('.').pop().toLowerCase();
    const fullRelPath = currentPath ? `${currentPath}/${name}` : name;
    const url = `/files/${encodeURIComponent(fullRelPath)}`;
    
    const isImg = ['jpg','jpeg','png','gif','webp','svg'].includes(ext);
    const isVid = ['mp4','mov','webm'].includes(ext);
    const isAudio = ['mp3','wav','ogg','m4a','flac','aac'].includes(ext);

    if (isImg || isVid) {
        openPreview(name, url, isImg ? 'img' : 'video');
    } else if (isAudio) {
        openAudio(name, url);
    } else {
        const a = document.createElement('a');
        a.href = url;
        a.download = name;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }
}

function openAudio(name, url) {
    const player = document.getElementById('mini-player');
    const audio = document.getElementById('audio-el');
    
    document.getElementById('mp-title').innerText = name;
    
    audio.dataset.downloadUrl = url;
    audio.dataset.downloadName = name;
    
    audio.src = url;
    audio.play();
    
    player.classList.add('active');
    updatePlayIcon(true);
    updateSeekFill();
}

function downloadAudio() {
    const audio = document.getElementById('audio-el');
    const url = audio.dataset.downloadUrl || audio.src;
    const name = audio.dataset.downloadName || 'audio.mp3';
    
    if (url) {
        const a = document.createElement('a');
        a.href = url;
        a.download = name;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }
}

function togglePlay() {
    const audio = document.getElementById('audio-el');
    if (audio.paused) {
        audio.play();
        updatePlayIcon(true);
    } else {
        audio.pause();
        updatePlayIcon(false);
    }
}

function updatePlayIcon(isPlaying) {
    const icon = document.getElementById('mp-play-icon');
    icon.className = isPlaying ? 'ph-fill ph-pause' : 'ph-fill ph-play';
}

function closeAudio() {
    const player = document.getElementById('mini-player');
    const audio = document.getElementById('audio-el');
    audio.pause();
    player.classList.remove('active');
}

function updateProgress() {
    if (isDraggingSeek) return;
    const audio = document.getElementById('audio-el');
    const seek = document.getElementById('mp-seek');
    const timeInfo = document.getElementById('mp-time');
    
    if (audio && audio.duration && seek) {
        seek.max = audio.duration;
        seek.value = audio.currentTime;
        timeInfo.innerText = formatTime(audio.currentTime) + ' / ' + formatTime(audio.duration);
        updateSeekFill();
    }
}

function seekAudio(val) {
    const audio = document.getElementById('audio-el');
    if(audio) audio.currentTime = val;
    updateSeekFill();
}

function updateSeekFill() {
    const seek = document.getElementById('mp-seek');
    if (!seek) return;
    
    const max = seek.max || 100;
    const val = seek.value || 0;
    const percent = (val / max) * 100;
    
    const fill = getComputedStyle(document.documentElement).getPropertyValue('--fg-primary').trim();
    const empty = getComputedStyle(document.documentElement).getPropertyValue('--bg-active').trim();
    
    const bg = `linear-gradient(to right, ${fill} 0%, ${fill} ${percent}%, ${empty} ${percent}%, ${empty} 100%)`;
    seek.style.background = bg;
}

function resetPlayer() {
    updatePlayIcon(false);
    const seek = document.getElementById('mp-seek');
    seek.value = 0;
    updateSeekFill();
    const audio = document.getElementById('audio-el');
    document.getElementById('mp-time').innerText = "0:00 / " + formatTime(audio ? audio.duration : 0);
}

function formatTime(seconds) {
    if (!seconds || isNaN(seconds)) return "0:00";
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
}

function openPreview(name, url, type) {
    const overlay = document.getElementById('preview-overlay');
    const content = document.getElementById('preview-content');
    const title = document.getElementById('preview-title');
    const dl = document.getElementById('preview-dl');

    title.innerText = name;
    dl.href = url;
    dl.download = name;

    if (type === 'img') {
        content.innerHTML = `<img src="${url}" class="preview-media" alt="${name}">`;
    } else {
        content.innerHTML = `<video src="${url}" class="preview-media" controls autoplay playsinline></video>`;
    }

    requestAnimationFrame(() => {
        overlay.classList.add('active');
    });
}

function closePreview() {
    const overlay = document.getElementById('preview-overlay');
    overlay.classList.remove('active');
    setTimeout(() => {
        document.getElementById('preview-content').innerHTML = '';
    }, 300);
}

function toggleMenu(id, e) {
    e.stopPropagation();
    const el = document.getElementById(id);
    const isActive = el.classList.contains('active');
    const fabBtn = document.getElementById('fab-btn');
    
    document.querySelectorAll('.dropdown-menu, .fab-menu').forEach(m => m.classList.remove('active'));
    if(fabBtn) fabBtn.classList.remove('active');
    
    if (!isActive) {
        el.classList.add('active');
        if(id === 'fab-menu' && fabBtn) fabBtn.classList.add('active');
    }
}

function closeAllMenus(e) {
    document.querySelectorAll('.dropdown-menu, .fab-menu').forEach(m => m.classList.remove('active'));
    const fabBtn = document.getElementById('fab-btn');
    if(fabBtn) fabBtn.classList.remove('active');
}

function triggerFile() { 
    document.getElementById('file-input').click(); 
}
function triggerFolder() { 
    document.getElementById('folder-input').click(); 
}

function handleFiles(files) {
    if (!permissions.write) {
        showToast("Uploads disabled");
        return;
    }
    Array.from(files).forEach(f => {
        let relPath = f.webkitRelativePath || f.name;
        if (currentPath) {
            relPath = currentPath + '/' + relPath;
        }
        uploadQueue.push({ file: f, path: relPath });
    });
    processNext();
}

async function processNext() {
    if (isUploading || !uploadQueue.length) return;
    isUploading = true;
    const item = uploadQueue.shift();
    
    showToast(`Uploading ${item.path}...`);
    try {
        const res = await fetch('/upload?name=' + encodeURIComponent(item.path), { method: 'POST', body: item.file });
        if (res.status === 403) {
            showToast('Upload forbidden');
        } else if (res.ok) {
            showToast('Uploaded');
        } else {
            showToast('Error uploading');
        }
    } catch(e) {
        showToast('Error uploading');
    }
    
    isUploading = false;
    if(uploadQueue.length) processNext();
    else {
        if(permissions.read) load();
        setTimeout(() => {
            const t = document.getElementById('toast');
            if(t) t.classList.remove('show');
        }, 2000);
    }
}

function showToast(msg) {
    const t = document.getElementById('toast');
    if(t) {
        t.innerText = msg;
        t.classList.add('show');
    }
}

function setupDrag() {
    const shade = document.getElementById('drag-shade');
    if(!shade) return;
    
    window.ondragover = e => { 
        if(!permissions.write) return;
        e.preventDefault(); 
        shade.classList.add('active'); 
    };
    window.ondragleave = e => { 
        if(!e.relatedTarget) shade.classList.remove('active'); 
    };
    window.ondrop = e => { 
        if(!permissions.write) return;
        e.preventDefault(); 
        shade.classList.remove('active');
        handleFiles(e.dataTransfer.files);
    };
}

function filter() {
    const term = document.getElementById('search').value.toLowerCase();
    render(currentFiles.filter(item => item.name.toLowerCase().includes(term)));
}

let allFiles = [];
let viewMode = localStorage.getItem('viewMode') || 'grid';
let uploadQueue = [];
let isUploading = false;
let isDraggingSeek = false;

document.addEventListener('DOMContentLoaded', () => {
    setView(viewMode);
    load();
    setupDrag();
    new EventSource("/events").onmessage = () => load();
    
    // Seek listeners
    const seek = document.getElementById('mp-seek');
    if (seek) {
        seek.addEventListener('mousedown', () => isDraggingSeek = true);
        seek.addEventListener('touchstart', () => isDraggingSeek = true);
        seek.addEventListener('mouseup', () => isDraggingSeek = false);
        seek.addEventListener('touchend', () => isDraggingSeek = false);
        updateSeekFill();
    }
});

function setView(mode) {
    viewMode = mode;
    localStorage.setItem('viewMode', mode);
    const el = document.getElementById('container');
    if(el) el.className = mode;
    const btnGrid = document.getElementById('btn-grid');
    const btnList = document.getElementById('btn-list');
    if(btnGrid) btnGrid.className = `view-btn ${mode === 'grid' ? 'active' : ''}`;
    if(btnList) btnList.className = `view-btn ${mode === 'list' ? 'active' : ''}`;
    render(allFiles);
}

async function load() {
    try {
        const res = await fetch('/list');
        allFiles = await res.json();
        render(allFiles);
    } catch (e) {}
}

function render(files) {
    const el = document.getElementById('container');
    if(!el) return;
    
    if (!files.length) {
        el.innerHTML = `
            <div class="empty" style="grid-column:1/-1;">
                <div class="empty-icon"><i class="ph-fill ph-upload-simple"></i></div>
                <h3>No Files</h3>
                <p>Drop files here or click upload to start sharing.</p>
            </div>`;
        return;
    }

    el.innerHTML = files.map(name => {
        const ext = name.split('.').pop().toLowerCase();
        const isImg = ['jpg','jpeg','png','gif','webp','svg'].includes(ext);
        const safe = name.replace(/'/g, "\\'");
        const url = `/files/${encodeURIComponent(name)}`;
        
        let icon = 'ph-file';
        if(['pdf'].includes(ext)) icon = 'ph-file-pdf';
        if(['mp4','mov','webm'].includes(ext)) icon = 'ph-film-strip';
        if(['zip','rar'].includes(ext)) icon = 'ph-archive';
        if(['mp3','wav','ogg','m4a','flac','aac'].includes(ext)) icon = 'ph-music-note';
        if(['txt','md','json'].includes(ext)) icon = 'ph-file-text';
        if(['html','css','js','py','swift'].includes(ext)) icon = 'ph-code';

        if (viewMode === 'grid') {
            const preview = isImg 
                ? `<img src="${url}" loading="lazy">` 
                : `<i class="ph-duotone ${icon}"></i>`;
            
            return `
            <div class="card" onclick="openFile('${safe}')">
                <div class="card-content">${preview}</div>
                <div class="card-info">
                    <div class="name">${name}</div>
                    <div class="ext">${ext.toUpperCase()}</div>
                </div>
            </div>`;
        } else {
            const preview = isImg 
                ? `<img src="${url}" loading="lazy">` 
                : `<i class="ph ${icon}"></i>`;

            return `
            <div class="row" onclick="openFile('${safe}')">
                <div class="row-icon">${preview}</div>
                <div class="row-name">${name}</div>
                <div class="row-size">${ext}</div>
            </div>`;
        }
    }).join('');
}

function openFile(name) {
    const ext = name.split('.').pop().toLowerCase();
    const url = `/files/${encodeURIComponent(name)}`;
    
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
        a.click();
    }
}

function openAudio(name, url) {
    const player = document.getElementById('mini-player');
    const audio = document.getElementById('audio-el');
    
    document.getElementById('mp-title').innerText = name;
    audio.src = url;
    audio.play();
    
    player.classList.add('active');
    updatePlayIcon(true);
    updateSeekFill();
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
    
    const bg = `linear-gradient(to right, var(--accent) 0%, var(--accent) ${percent}%, var(--bg-surface) ${percent}%, var(--bg-surface) 100%)`;
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
        content.innerHTML = `<img src="${url}" class="preview-media">`;
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
    Array.from(files).forEach(f => uploadQueue.push({ file: f, path: f.webkitRelativePath || f.name }));
    processNext();
}

async function processNext() {
    if (isUploading || !uploadQueue.length) return;
    isUploading = true;
    const item = uploadQueue.shift();
    
    showToast(`Uploading ${item.path}...`);
    try {
        await fetch('/upload?name=' + encodeURIComponent(item.path), { method: 'POST', body: item.file });
        showToast('Uploaded');
    } catch(e) {
        showToast('Error uploading');
    }
    
    isUploading = false;
    if(uploadQueue.length) processNext();
    else setTimeout(() => {
        const t = document.getElementById('toast');
        if(t) t.classList.remove('show');
    }, 2000);
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
    window.ondragover = e => { e.preventDefault(); shade.classList.add('active'); };
    window.ondragleave = e => { if(!e.relatedTarget) shade.classList.remove('active'); };
    window.ondrop = e => { 
        e.preventDefault(); shade.classList.remove('active');
        handleFiles(e.dataTransfer.files);
    };
}

function filter() {
    const term = document.getElementById('search').value.toLowerCase();
    render(allFiles.filter(f => f.toLowerCase().includes(term)));
}
const wheelCanvas = document.getElementById('color-wheel');
const wheelCtx = wheelCanvas.getContext('2d');
const wheelCursor = document.getElementById('wheel-cursor');
const previewColor = document.getElementById('cp-current-color');
const hexValue = document.getElementById('cp-hex-value');
const controlPanel = document.getElementById('control-panel-ui');
const placementUI = document.getElementById('placement-ui');
const uiControls = document.getElementById('ui-controls');

const brightnessSlider = document.getElementById('brightness-slider');
const brightnessHandle = document.getElementById('brightness-handle');
const brightnessFill = document.getElementById('brightness-fill');
const brightnessValueEl = document.getElementById('brightness-value');

const bvSlider = document.getElementById('bv-slider');
const bvHandle = document.getElementById('bv-handle');
const bvFill = document.getElementById('bv-fill');

const wheelSize = wheelCanvas.width;
const wheelCenter = wheelSize / 2;

let currentH = 0;
let currentS = 0;
let currentV = 1;
let currentB = 8.0;
let minB = 0.5;
let maxB = 10.0;
let currentNetId = null;

let isDraggingWheel = false;
let isDraggingBrightness = false;
let isDraggingBV = false;

function hsvToRgb(h, s, v) {
    let r, g, b;
    let i = Math.floor(h / 60) % 6;
    let f = h / 60 - Math.floor(h / 60);
    let p = v * (1 - s);
    let q = v * (1 - f * s);
    let t = v * (1 - (1 - f) * s);
    switch(i) {
        case 0: r = v; g = t; b = p; break;
        case 1: r = q; g = v; b = p; break;
        case 2: r = p; g = v; b = t; break;
        case 3: r = p; g = q; b = v; break;
        case 4: r = t; g = p; b = v; break;
        case 5: r = v; g = p; b = q; break;
    }
    return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)];
}

function rgbToHsv(r, g, b) {
    r /= 255, g /= 255, b /= 255;
    let max = Math.max(r, g, b), min = Math.min(r, g, b);
    let h, s, v = max;
    let d = max - min;
    s = max == 0 ? 0 : d / max;
    if(max == min){
        h = 0;
    } else {
        switch(max){
            case r: h = (g - b) / d + (g < b ? 6 : 0); break;
            case g: h = (b - r) / d + 2; break;
            case b: h = (r - g) / d + 4; break;
        }
        h /= 6;
    }
    return [h * 360, s, v];
}

function rgbToHex(r, g, b) {
    return "#" + (1 << 24 | r << 16 | g << 8 | b).toString(16).slice(1).toUpperCase();
}

function drawColorWheel() {
    const img = wheelCtx.createImageData(wheelSize, wheelSize);
    for(let y = 0; y < wheelSize; y++) {
        for(let x = 0; x < wheelSize; x++) {
            const i = (y * wheelSize + x) * 4;
            const dx = x - wheelCenter;
            const dy = y - wheelCenter;
            const dist = Math.sqrt(dx*dx + dy*dy);
            if(dist <= wheelCenter) {
                let angle = Math.atan2(dy, dx);
                if(angle < 0) angle += Math.PI * 2;
                let hue = (angle * 180 / Math.PI);
                let sat = dist / wheelCenter;
                let [r, g, b] = hsvToRgb(hue, sat, 1);
                img.data[i] = r;
                img.data[i+1] = g;
                img.data[i+2] = b;
                img.data[i+3] = 255;
            }
        }
    }
    wheelCtx.putImageData(img, 0, 0);
}

function updateUI() {
    const [r, g, b] = hsvToRgb(currentH, currentS, currentV);
    const hex = rgbToHex(r, g, b);
    previewColor.style.background = hex;
    hexValue.innerText = hex;

    let angle = currentH * Math.PI / 180;
    let dist = currentS * wheelCenter;
    let cx = wheelCenter + Math.cos(angle) * dist;
    let cy = wheelCenter + Math.sin(angle) * dist;
    wheelCursor.style.left = cx + 'px';
    wheelCursor.style.top = cy + 'px';
    wheelCursor.style.background = hex;

    let bPercent = (currentB - minB) / (maxB - minB);
    brightnessHandle.style.left = (bPercent * 100) + '%';
    brightnessFill.style.width = (bPercent * 100) + '%';
    brightnessValueEl.innerText = currentB.toFixed(1);

    bvHandle.style.left = (currentV * 100) + '%';
    bvFill.style.width = (currentV * 100) + '%';
    
    const [hr, hg, hb] = hsvToRgb(currentH, currentS, 1);
    bvFill.style.background = `linear-gradient(to right, #000, rgb(${hr},${hg},${hb}))`;
    bvHandle.style.background = hex;
    brightnessHandle.style.background = hex;
}

let lastUpdate = 0;
function sendLiveUpdate() {
    const [r, g, b] = hsvToRgb(currentH, currentS, currentV);
    const now = Date.now();
    if(now - lastUpdate > 40) {
        lastUpdate = now;
        fetch(`https://${GetParentResourceName()}/liveUpdateColor`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                netId: parseInt(currentNetId),
                r: r,
                g: g,
                b: b
            })
        });
        fetch(`https://${GetParentResourceName()}/liveUpdateBrightness`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                netId: parseInt(currentNetId),
                brightness: currentB
            })
        });
    }
}

function updateWheel(e) {
    const rect = wheelCanvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const dx = x - wheelCenter;
    const dy = y - wheelCenter;
    const dist = Math.sqrt(dx*dx + dy*dy);
    
    let angle = Math.atan2(dy, dx);
    if(angle < 0) angle += Math.PI * 2;
    currentH = (angle * 180 / Math.PI);
    currentS = Math.min(1, dist / wheelCenter);
    
    updateUI();
    sendLiveUpdate();
}

function updateBrightnessSlider(e) {
    const rect = brightnessSlider.getBoundingClientRect();
    const x = Math.max(0, Math.min(rect.width, e.clientX - rect.left));
    let percent = x / rect.width;
    currentB = minB + (percent * (maxB - minB));
    updateUI();
    sendLiveUpdate();
}

function updateBVSlider(e) {
    const rect = bvSlider.getBoundingClientRect();
    const x = Math.max(0, Math.min(rect.width, e.clientX - rect.left));
    currentV = x / rect.width;
    updateUI();
    sendLiveUpdate();
}

wheelCanvas.addEventListener('mousedown', (e) => {
    isDraggingWheel = true;
    updateWheel(e);
});

brightnessSlider.addEventListener('mousedown', (e) => {
    isDraggingBrightness = true;
    updateBrightnessSlider(e);
});

bvSlider.addEventListener('mousedown', (e) => {
    isDraggingBV = true;
    updateBVSlider(e);
});

document.addEventListener('mousemove', (e) => {
    if(isDraggingWheel) updateWheel(e);
    if(isDraggingBrightness) updateBrightnessSlider(e);
    if(isDraggingBV) updateBVSlider(e);
});

document.addEventListener('mouseup', () => {
    isDraggingWheel = false;
    isDraggingBrightness = false;
    isDraggingBV = false;
});

window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'show') {
        uiControls.innerHTML = '';
        if (data.controls) {
            data.controls.forEach((ctrl, index) => {
                if (index > 0) {
                    const divider = document.createElement('div');
                    divider.className = 'control-divider';
                    uiControls.appendChild(divider);
                }
                
                const group = document.createElement('div');
                group.className = 'control-group';
                group.innerHTML = `
                    <div class="control-btn">
                        <div class="ctrl-key">${ctrl.key}</div>
                        <div class="ctrl-text">${ctrl.action}</div>
                    </div>
                `;
                uiControls.appendChild(group);
            });
        }
        
        placementUI.style.display = 'flex';
    } 
    else if (data.action === 'hide') {
        placementUI.style.display = 'none';
    }
    else if (data.action === 'hideControlPanel') {
        controlPanel.style.display = 'none';
    }
    else if (data.action === 'openControlPanel') {
        currentNetId = data.netId;
        minB = data.minBrightness;
        maxB = data.maxBrightness;
        currentB = data.brightness;
        
        let r = 255, g = 255, b = 255;
        if(data.color && typeof data.color === 'object') {
            r = data.color.r || 255;
            g = data.color.g || 255;
            b = data.color.b || 255;
        }
        
        let [h, s, v] = rgbToHsv(r, g, b);
        currentH = h;
        currentS = s;
        currentV = v;
        
        drawColorWheel();
        updateUI();
        controlPanel.style.display = 'block';
    }
});

document.getElementById('cp-confirm').addEventListener('click', function() {
    const [r, g, b] = hsvToRgb(currentH, currentS, currentV);
    fetch(`https://${GetParentResourceName()}/saveControlPanel`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({
            netId: parseInt(currentNetId),
            r: r,
            g: g,
            b: b,
            brightness: currentB
        })
    }).then(() => {
        controlPanel.style.display = 'none';
    });
});

document.getElementById('cp-cancel').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/closeControlPanel`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    }).then(() => {
        controlPanel.style.display = 'none';
    });
});

document.getElementById('cp-sync').addEventListener('click', function() {
    const [r, g, b] = hsvToRgb(currentH, currentS, currentV);
    fetch(`https://${GetParentResourceName()}/syncAllLights`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({
            r: r,
            g: g,
            b: b,
            brightness: currentB
        })
    }).then(() => {
        controlPanel.style.display = 'none';
    });
});

drawColorWheel();
updateUI();
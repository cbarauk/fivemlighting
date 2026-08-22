const wheelCanvas = document.getElementById('color-wheel');
const wheelCtx = wheelCanvas.getContext('2d');
const wheelCursor = document.getElementById('wheel-cursor');
const previewColor = document.getElementById('cp-current-color');
const hexValue = document.getElementById('cp-hex-value');
const controlPanel = document.getElementById('control-panel-ui');
const placementUI = document.getElementById('placement-ui');
const uiControls = document.getElementById('ui-controls');
const shopUI = document.getElementById('shop-ui');
const shopView = document.getElementById('shop-view');
const cartView = document.getElementById('cart-view');
const cartItemsContainer = document.getElementById('cart-items-container');

const brightnessSlider = document.getElementById('brightness-slider');
const brightnessHandle = document.getElementById('brightness-handle');
const brightnessFill = document.getElementById('brightness-fill');
const brightnessValueEl = document.getElementById('brightness-value');

const distanceSlider = document.getElementById('distance-slider');
const distanceHandle = document.getElementById('distance-handle');
const distanceFill = document.getElementById('distance-fill');
const distanceValueEl = document.getElementById('distance-value');

const widthSlider = document.getElementById('width-slider');
const widthHandle = document.getElementById('width-handle');
const widthFill = document.getElementById('width-fill');
const widthValueEl = document.getElementById('width-value');

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

let currentDist = 25.0;
let minDist = 1.0;
let maxDist = 50.0;

let currentWidth = 25.0;
let minWidth = 1.0;
let maxWidth = 50.0;

let currentNetId = null;

let isDraggingWheel = false;
let isDraggingBrightness = false;
let isDraggingDistance = false;
let isDraggingWidth = false;
let isDraggingBV = false;

let shopItems = {};
let cart = {};

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
    brightnessHandle.style.background = hex;

    let dPercent = (currentDist - minDist) / (maxDist - minDist);
    distanceHandle.style.left = (dPercent * 100) + '%';
    distanceFill.style.width = (dPercent * 100) + '%';
    distanceValueEl.innerText = currentDist.toFixed(1);
    distanceHandle.style.background = hex;

    let wPercent = (currentWidth - minWidth) / (maxWidth - minWidth);
    widthHandle.style.left = (wPercent * 100) + '%';
    widthFill.style.width = (wPercent * 100) + '%';
    widthValueEl.innerText = currentWidth.toFixed(1);
    widthHandle.style.background = hex;

    bvHandle.style.left = (currentV * 100) + '%';
    bvFill.style.width = (currentV * 100) + '%';
    
    const [hr, hg, hb] = hsvToRgb(currentH, currentS, 1);
    bvFill.style.background = `linear-gradient(to right, #000, rgb(${hr},${hg},${hb}))`;
    bvHandle.style.background = hex;
}

let lastUpdate = 0;
function sendLiveUpdate() {
    if (currentNetId == null) return;
    
    const [r, g, b] = hsvToRgb(currentH, currentS, currentV);
    const now = Date.now();
    if(now - lastUpdate > 40) {
        lastUpdate = now;
        fetch(`https://${GetParentResourceName()}/liveUpdate`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                netId: parseInt(currentNetId),
                r: r,
                g: g,
                b: b,
                brightness: currentB,
                distance: currentDist,
                width: currentWidth
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

function updateDistanceSlider(e) {
    const rect = distanceSlider.getBoundingClientRect();
    const x = Math.max(0, Math.min(rect.width, e.clientX - rect.left));
    let percent = x / rect.width;
    currentDist = minDist + (percent * (maxDist - minDist));
    updateUI();
    sendLiveUpdate();
}

function updateWidthSlider(e) {
    const rect = widthSlider.getBoundingClientRect();
    const x = Math.max(0, Math.min(rect.width, e.clientX - rect.left));
    let percent = x / rect.width;
    currentWidth = minWidth + (percent * (maxWidth - minWidth));
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

distanceSlider.addEventListener('mousedown', (e) => {
    isDraggingDistance = true;
    updateDistanceSlider(e);
});

widthSlider.addEventListener('mousedown', (e) => {
    isDraggingWidth = true;
    updateWidthSlider(e);
});

bvSlider.addEventListener('mousedown', (e) => {
    isDraggingBV = true;
    updateBVSlider(e);
});

document.addEventListener('mousemove', (e) => {
    if(isDraggingWheel) updateWheel(e);
    if(isDraggingBrightness) updateBrightnessSlider(e);
    if(isDraggingDistance) updateDistanceSlider(e);
    if(isDraggingWidth) updateWidthSlider(e);
    if(isDraggingBV) updateBVSlider(e);
});

document.addEventListener('mouseup', () => {
    isDraggingWheel = false;
    isDraggingBrightness = false;
    isDraggingDistance = false;
    isDraggingWidth = false;
    isDraggingBV = false;
});

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        if (controlPanel.style.display === 'block') {
            document.getElementById('cp-cancel').click();
        } else if (shopUI.style.display === 'flex') {
            if (cartView.style.display === 'flex') {
                document.getElementById('back-btn').click();
            } else {
                document.getElementById('shop-close-btn').click();
            }
        }
    }
});

function updateCartTotals() {
    let total = 0;
    for (let item in cart) {
        total += (shopItems[item].price * cart[item]);
    }
    document.getElementById('shop-cart-total').innerText = '$' + total;
    document.getElementById('cart-total-val').innerText = '$' + total;
}

function renderCart() {
    cartItemsContainer.innerHTML = '';
    let hasItems = false;

    for (let item in cart) {
        if (cart[item] > 0) {
            hasItems = true;
            let itemData = shopItems[item];
            let div = document.createElement('div');
            div.className = 'cart-item';
            div.innerHTML = `
                <div class="cart-item-icon">
                    <img src="nui://qb-inventory/html/images/${item}.png" alt="${item}">
                </div>
                <div class="cart-item-details">
                    <h4>Portable Studio Light</h4>
                    <div class="cart-item-price">$${itemData.price} each</div>
                </div>
                <div class="cart-qty">
                    <div class="qty-btn cart-minus" data-item="${item}"><i class="fas fa-minus"></i></div>
                    <div class="qty-val">${cart[item]}</div>
                    <div class="qty-btn cart-plus" data-item="${item}"><i class="fas fa-plus"></i></div>
                </div>
            `;
            cartItemsContainer.appendChild(div);
        }
    }

    if (!hasItems) {
        cartItemsContainer.innerHTML = '<div class="cart-empty">Your cart is empty.</div>';
    }

    document.querySelectorAll('.cart-plus').forEach(btn => {
        btn.addEventListener('click', function() {
            let item = this.getAttribute('data-item');
            cart[item]++;
            renderCart();
            updateCartTotals();
        });
    });

    document.querySelectorAll('.cart-minus').forEach(btn => {
        btn.addEventListener('click', function() {
            let item = this.getAttribute('data-item');
            cart[item]--;
            if (cart[item] <= 0) delete cart[item];
            renderCart();
            updateCartTotals();
        });
    });

    updateCartTotals();
}

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
        currentDist = data.distance;
        currentWidth = data.width;
        
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
        
        updateUI();
        controlPanel.style.display = 'block';
    }
    else if (data.action === 'openShop') {
        shopItems = data.items;
        cart = {};
        
        for (let item in shopItems) {
            let priceEl = document.getElementById(`price-${item}`);
            if (priceEl) priceEl.innerText = shopItems[item].price;
        }

        shopView.style.display = 'flex';
        cartView.style.display = 'none';
        updateCartTotals();
        shopUI.style.display = 'flex';
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
            brightness: currentB,
            distance: currentDist,
            width: currentWidth
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

document.getElementById('shop-close-btn').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/closeShop`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    }).then(() => {
        shopUI.style.display = 'none';
    });
});

document.getElementById('cart-close-btn').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/closeShop`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    }).then(() => {
        shopUI.style.display = 'none';
    });
});

document.querySelectorAll('.add-cart-btn').forEach(btn => {
    btn.addEventListener('click', function() {
        let item = this.getAttribute('data-item');
        cart[item] = (cart[item] || 0) + 1;
        updateCartTotals();
        
        this.innerHTML = '<i class="fas fa-check"></i> Added';
        setTimeout(() => {
            this.innerHTML = '<i class="fas fa-cart-plus"></i> Add to Cart';
        }, 1000);
    });
});

document.getElementById('checkout-btn').addEventListener('click', function() {
    shopView.style.display = 'none';
    cartView.style.display = 'flex';
    renderCart();
});

document.getElementById('back-btn').addEventListener('click', function() {
    cartView.style.display = 'none';
    shopView.style.display = 'flex';
});

document.getElementById('shop-cash-btn').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/processPurchase`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({
            cart: cart,
            paymentType: 'cash'
        })
    }).then(() => {
        shopUI.style.display = 'none';
    });
});

document.getElementById('shop-card-btn').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/processPurchase`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({
            cart: cart,
            paymentType: 'bank'
        })
    }).then(() => {
        shopUI.style.display = 'none';
    });
});

drawColorWheel();
updateUI();
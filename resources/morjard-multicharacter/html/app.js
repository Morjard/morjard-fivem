/* ============================================================
   MORJARD MULTICHARACTER — UI Logic
   ============================================================ */

let characters = [];
let maxSlots = 4;
let selectedSlot = -1;
let selectedChar = null;
let createSlotCid = 1;
let currentGender = 0;
let headshotUrls = {};  // citizenid → headshot URL

// ============================================================
// NUI FETCH HELPER
// ============================================================

async function fetchNui(event, data = {}) {
    try {
        const resp = await fetch(`https://morjard-multicharacter/${event}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        const text = await resp.text();
        try { return JSON.parse(text); } catch { return text; }
    } catch (e) {
        return null;
    }
}

// ============================================================
// NUI MESSAGE LISTENER
// ============================================================

window.addEventListener('message', (e) => {
    const data = e.data;

    switch (data.action) {
        case 'open':
            maxSlots = data.maxSlots || 4;
            characters = data.characters || [];
            if (data.spawnLocations) {
                setSpawnLocations(data.spawnLocations, data.enableLastLocation);
            }
            openUI();
            break;

        case 'refreshCharacters':
            characters = data.characters || [];
            if (data.maxSlots) maxSlots = data.maxSlots;
            renderSlots();
            // Select first existing character or deselect
            let firstRefresh = -1;
            for (let i = 0; i < maxSlots; i++) {
                if (getCharForSlot(i + 1)) { firstRefresh = i; break; }
            }
            if (firstRefresh >= 0) {
                selectSlot(firstRefresh);
            } else {
                deselectAll();
            }
            break;

        case 'updateHeadshot':
            if (data.citizenid && data.headshotUrl) {
                headshotUrls[data.citizenid] = data.headshotUrl;
                updateSlotPhoto(data.citizenid, data.headshotUrl);
            }
            break;

        case 'close':
            closeUI();
            break;
    }
});

// ============================================================
// OPEN / CLOSE
// ============================================================

function toggleAmbientEffects(show) {
    document.querySelectorAll('.grid-bg, .glow-orb, .particle').forEach(el => {
        el.style.display = show ? '' : 'none';
    });
}

function updateSlotPhoto(citizenid, url) {
    // Sanitize citizenid for CSS selector (prevent selector injection)
    const safeCid = String(citizenid).replace(/[^a-zA-Z0-9_-]/g, '');
    if (!safeCid) return;
    const img = document.querySelector(`.slot-photo[data-cid="${safeCid}"]`);
    if (img) {
        img.src = url + '?t=' + Date.now();
        img.classList.add('loaded');
    }
}

function openUI() {
    headshotUrls = {};
    const el = document.getElementById('multichar');
    el.classList.remove('hidden');
    toggleAmbientEffects(true);

    renderSlots();

    // Auto-select first existing character
    let firstIdx = -1;
    for (let i = 0; i < maxSlots; i++) {
        if (getCharForSlot(i + 1)) { firstIdx = i; break; }
    }
    if (firstIdx >= 0) {
        selectSlot(firstIdx);
    } else {
        deselectAll();
        showPanel();
    }
}

function closeUI() {
    const el = document.getElementById('multichar');
    el.classList.add('hidden');
    toggleAmbientEffects(false);
    document.getElementById('createModal').classList.add('hidden');
    document.getElementById('deleteModal').classList.add('hidden');
    document.getElementById('spawnModal').classList.add('hidden');
}

// ============================================================
// RENDER SLOTS
// ============================================================

// Get character for a given slot (1-indexed cid)
function getCharForSlot(slotCid) {
    if (!characters || !characters.length) return null;
    return characters.find(c => c && c.cid === slotCid) || null;
}

function renderSlots() {
    const carousel = document.getElementById('carousel');
    carousel.innerHTML = '';

    for (let i = 0; i < maxSlots; i++) {
        const slotCid = i + 1; // slots are 1-indexed (cid)
        const char = getCharForSlot(slotCid);
        const card = document.createElement('div');
        card.className = 'slot-card' + (char ? '' : ' empty') + (i === selectedSlot ? ' active' : '');
        card.dataset.slot = i;

        // Corner brackets
        const corners = '<div class="wc tl"></div><div class="wc tr"></div><div class="wc bl"></div><div class="wc br"></div>';

        if (char) {
            const ci = char.charinfo || {};
            const job = char.job || {};
            const name = `${ci.firstname || '?'} ${ci.lastname || '?'}`;
            const jobLabel = job.label || 'Unemployed';
            const cachedUrl = headshotUrls[char.citizenid];
            const photoClass = cachedUrl ? 'slot-photo loaded' : 'slot-photo';
            const photoSrc = cachedUrl ? cachedUrl + '?t=' + Date.now() : '';

            card.innerHTML = `
                ${corners}
                <div class="slot-photo-wrap">
                    <img class="${photoClass}" data-cid="${escHtml(char.citizenid)}" src="${escHtml(photoSrc)}" alt="">
                    <div class="slot-photo-fallback"><i class="fas fa-user"></i></div>
                </div>
                <div class="slot-info">
                    <div class="slot-top">
                        <div class="slot-number">${String(i + 1).padStart(2, '0')}</div>
                        <div class="slot-name">${escHtml(name)}</div>
                    </div>
                    <div class="slot-bottom">
                        <div class="slot-job">${escHtml(jobLabel)}</div>
                        <div class="slot-indicator"></div>
                    </div>
                </div>
            `;
        } else {
            card.innerHTML = `
                ${corners}
                <div class="slot-empty-icon">
                    <i class="fas fa-plus"></i>
                    <span>NEW</span>
                </div>
            `;
        }

        card.addEventListener('click', () => {
            if (char) {
                selectSlot(i);
            } else {
                openCreateModal(slotCid);
            }
        });

        carousel.appendChild(card);
    }
}

// ============================================================
// SELECT SLOT
// ============================================================

function selectSlot(index) {
    const slotCid = index + 1;
    const char = getCharForSlot(slotCid);
    if (!char) return;

    selectedSlot = index;
    selectedChar = char;

    // Update active class
    document.querySelectorAll('.slot-card').forEach((c, i) => {
        c.classList.toggle('active', i === index);
    });

    // Update top bar name
    const ci = char.charinfo || {};
    const name = `${ci.firstname || ''} ${ci.lastname || ''}`.trim().toUpperCase();
    document.getElementById('charName').textContent = name || 'SELECT CHARACTER';

    // Update info panel
    showCharInfo(char);

    // Notify Lua to preview ped
    fetchNui('previewCharacter', { citizenid: char.citizenid });
}

function deselectAll() {
    selectedSlot = -1;
    selectedChar = null;
    document.querySelectorAll('.slot-card').forEach(c => c.classList.remove('active'));
    document.getElementById('charName').textContent = 'SELECT CHARACTER';
    document.getElementById('infoContent').classList.add('hidden');
    document.getElementById('infoEmpty').classList.remove('hidden');
}

function showPanel() {
    const panel = document.getElementById('infoPanel');
    panel.classList.add('visible');
}

function showCharInfo(char) {
    const ci = char.charinfo || {};
    const money = char.money || {};
    const job = char.job || {};

    document.getElementById('infoEmpty').classList.add('hidden');
    document.getElementById('infoContent').classList.remove('hidden');

    document.getElementById('infoCid').textContent = char.citizenid || 'UNKNOWN';
    document.getElementById('infoName').textContent = `${ci.firstname || '?'} ${ci.lastname || '?'}`;
    document.getElementById('infoDob').textContent = ci.birthdate || '—';
    document.getElementById('infoGender').textContent = ci.gender === 1 ? 'Female' : 'Male';
    document.getElementById('infoNationality').textContent = ci.nationality || '—';
    document.getElementById('infoJob').textContent = job.label || 'Unemployed';
    document.getElementById('infoCash').textContent = '$' + formatMoney(money.cash || 0);
    document.getElementById('infoBank').textContent = '$' + formatMoney(money.bank || 0);

    showPanel();
}

// ============================================================
// PLAY / DELETE
// ============================================================

document.getElementById('btnPlay').addEventListener('click', () => {
    if (!selectedChar) return;
    openSpawnSelector();
});

document.getElementById('btnDelete').addEventListener('click', () => {
    if (!selectedChar) return;
    openDeleteModal(selectedChar);
});

document.getElementById('btnDisconnect').addEventListener('click', () => {
    fetchNui('disconnect');
});

// ============================================================
// CREATE CHARACTER MODAL
// ============================================================

function openCreateModal(cid) {
    createSlotCid = cid;
    currentGender = 0;

    // Reset form
    document.getElementById('inputFirstname').value = '';
    document.getElementById('inputLastname').value = '';
    document.getElementById('inputDob').value = '1990-01-01';
    document.getElementById('inputNationality').value = 'Czech Republic';
    setGenderButton(0);

    document.getElementById('createModal').classList.remove('hidden');

    // Preview default ped
    fetchNui('previewCharacter', { gender: 0 });

    // Focus first input
    setTimeout(() => document.getElementById('inputFirstname').focus(), 100);
}

document.getElementById('btnCancelCreate').addEventListener('click', () => {
    document.getElementById('createModal').classList.add('hidden');
    // Restore previous preview
    if (selectedChar) {
        fetchNui('previewCharacter', { citizenid: selectedChar.citizenid });
    }
});

document.getElementById('btnConfirmCreate').addEventListener('click', () => {
    const firstname = document.getElementById('inputFirstname').value.trim();
    const lastname = document.getElementById('inputLastname').value.trim();
    const dob = document.getElementById('inputDob').value;
    const nationality = document.getElementById('inputNationality').value || 'Czech Republic';

    if (!firstname || !lastname) {
        shakeElement(document.getElementById('inputFirstname'));
        shakeElement(document.getElementById('inputLastname'));
        return;
    }

    // Profanity filter
    if (containsProfanity(firstname) || containsProfanity(lastname)) {
        shakeElement(document.getElementById('inputFirstname'));
        shakeElement(document.getElementById('inputLastname'));
        return;
    }

    // Name must be letters only (allow accents, hyphens, spaces)
    const nameRegex = /^[a-zA-ZÀ-ž\s'-]{2,30}$/;
    if (!nameRegex.test(firstname)) {
        shakeElement(document.getElementById('inputFirstname'));
        return;
    }
    if (!nameRegex.test(lastname)) {
        shakeElement(document.getElementById('inputLastname'));
        return;
    }

    // Date of birth validation (min 1900, max 16 years ago)
    if (dob) {
        const dobDate = new Date(dob);
        const minDate = new Date('1900-01-01');
        const maxDate = new Date();
        maxDate.setFullYear(maxDate.getFullYear() - 16);
        if (dobDate < minDate || dobDate > maxDate) {
            shakeElement(document.getElementById('inputDob'));
            return;
        }
    }

    fetchNui('createCharacter', {
        cid: createSlotCid,
        firstname: firstname,
        lastname: lastname,
        birthdate: dob,
        gender: currentGender,
        nationality: nationality,
    });

    document.getElementById('createModal').classList.add('hidden');
});

// Gender toggle
document.querySelectorAll('.gender-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        currentGender = parseInt(btn.dataset.gender);
        setGenderButton(currentGender);
        fetchNui('previewCharacter', { gender: currentGender });
    });
});

function setGenderButton(gender) {
    document.getElementById('genderMale').classList.toggle('active', gender === 0);
    document.getElementById('genderFemale').classList.toggle('active', gender === 1);
}

// ============================================================
// DELETE MODAL
// ============================================================

let deleteTarget = null;

function openDeleteModal(char) {
    deleteTarget = char;
    const ci = char.charinfo || {};
    const fullName = `${ci.firstname || ''} ${ci.lastname || ''}`.trim().toUpperCase();

    document.getElementById('deleteCharName').textContent = fullName;
    document.getElementById('inputDeleteConfirm').value = '';
    document.getElementById('btnConfirmDelete').classList.add('disabled');
    document.getElementById('deleteModal').classList.remove('hidden');

    setTimeout(() => document.getElementById('inputDeleteConfirm').focus(), 100);
}

document.getElementById('inputDeleteConfirm').addEventListener('input', (e) => {
    if (!deleteTarget) return;
    const ci = deleteTarget.charinfo || {};
    const fullName = `${ci.firstname || ''} ${ci.lastname || ''}`.trim().toUpperCase();
    const typed = e.target.value.trim().toUpperCase();

    document.getElementById('btnConfirmDelete').classList.toggle('disabled', typed !== fullName);
});

document.getElementById('btnCancelDelete').addEventListener('click', () => {
    document.getElementById('deleteModal').classList.add('hidden');
    deleteTarget = null;
});

document.getElementById('btnConfirmDelete').addEventListener('click', () => {
    if (!deleteTarget) return;
    if (document.getElementById('btnConfirmDelete').classList.contains('disabled')) return;

    fetchNui('deleteCharacter', { citizenid: deleteTarget.citizenid });
    document.getElementById('deleteModal').classList.add('hidden');
    deleteTarget = null;
});

// ============================================================
// PROFANITY FILTER
// ============================================================

const profanityList = [
    'admin','moderator','owner','server','console','system',
    'nigger','nigga','faggot','retard','fuck','shit','ass','dick',
    'penis','vagina','cock','pussy','bitch','whore','slut',
    'kurva','pica','kokot','debil','zmrd','hajzl','srac','piča','čurák','vole'
];
// Use word boundaries to prevent false positives (e.g. "Cassidy" matching "ass")
const profanityRegex = new RegExp('\\b(' + profanityList.join('|') + ')\\b', 'i');
// Also check without boundaries for short inputs (2-4 chars that ARE the profanity)
const profanityExactRegex = new RegExp('^(' + profanityList.join('|') + ')$', 'i');

// Cyrillic→Latin homoglyph map (common lookalikes)
const cyrillicMap = { 'а':'a','е':'e','о':'o','р':'p','с':'c','у':'y','х':'x','і':'i','ј':'j','ѕ':'s','ь':'b' };

function containsProfanity(text) {
    // 1. Strip zero-width characters (U+200B-200F, U+FEFF, U+00AD, etc.)
    let clean = text.replace(/[\u200B-\u200F\u2028-\u202F\uFEFF\u00AD\u034F\u061C\u180E]/g, '');
    // 2. Normalize unicode (decompose accented chars, strip combining marks)
    clean = clean.normalize('NFKD').replace(/[\u0300-\u036f]/g, '');
    // 3. Replace Cyrillic homoglyphs with Latin equivalents
    clean = clean.replace(/[а-яА-ЯіјѕьІЈЅЬ]/g, ch => cyrillicMap[ch.toLowerCase()] || ch);
    // 4. Test with word boundaries (prevents "Cassidy" matching "ass")
    if (profanityRegex.test(clean) || profanityRegex.test(text)) return true;
    // 5. Exact match for very short inputs
    if (profanityExactRegex.test(clean)) return true;
    return false;
}

// ============================================================
// HELPERS
// ============================================================

function formatMoney(num) {
    return Number(num).toLocaleString('en-US');
}

function escHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

function shakeElement(el) {
    el.style.animation = 'none';
    el.offsetHeight; // force reflow
    el.style.animation = 'shake 0.4s ease';
    el.style.borderColor = 'var(--danger)';
    setTimeout(() => {
        el.style.borderColor = '';
        el.style.animation = '';
    }, 600);
}

// Shake animation (injected dynamically)
const style = document.createElement('style');
style.textContent = `
    @keyframes shake {
        0%, 100% { transform: translateX(0); }
        20% { transform: translateX(-6px); }
        40% { transform: translateX(5px); }
        60% { transform: translateX(-4px); }
        80% { transform: translateX(3px); }
    }
`;
document.head.appendChild(style);

// ============================================================
// SPAWN LOCATION SELECTOR
// ============================================================

let spawnLocations = [];
let selectedSpawnId = null;
let lastLocationEnabled = true;

function setSpawnLocations(locs, enableLast) {
    spawnLocations = locs || [];
    lastLocationEnabled = enableLast !== false;
}

function openSpawnSelector() {
    // Guard: skip spawn selector if no locations available
    if (spawnLocations.length === 0 && !lastLocationEnabled) {
        fetchNui('selectCharacter', { citizenid: selectedChar.citizenid, spawnLocation: null });
        return;
    }

    selectedSpawnId = null;
    document.getElementById('btnSpawn').classList.add('disabled');
    document.getElementById('spawnLocationName').textContent = 'SELECT A LOCATION';
    document.getElementById('spawnLocationInfo').classList.remove('selected');
    document.getElementById('btnLastLocation').classList.remove('active');

    // Show/hide last location button
    document.getElementById('btnLastLocation').style.display = lastLocationEnabled ? '' : 'none';

    renderSpawnPins();
    document.getElementById('spawnModal').classList.remove('hidden');
}

function closeSpawnSelector() {
    document.getElementById('spawnModal').classList.add('hidden');
    selectedSpawnId = null;
}

// Convert GTA V game coords to map percentage
function gameToMap(x, y) {
    return {
        x: (x + 5500) / 12000 * 100,
        y: (8000 - y) / 12000 * 100,
    };
}

function renderSpawnPins() {
    const map = document.getElementById('spawnMap');
    // Clear existing pins
    map.querySelectorAll('.spawn-pin').forEach(p => p.remove());

    spawnLocations.forEach(loc => {
        const pin = document.createElement('div');
        pin.className = 'spawn-pin';
        // Calculate position from game coords, fallback to mapX/mapY
        const pos = (loc.x != null && loc.y != null) ? gameToMap(loc.x, loc.y)
                  : (loc.mapX != null) ? { x: loc.mapX, y: loc.mapY }
                  : gameToMap(0, 0);
        pin.style.left = pos.x + '%';
        pin.style.top = pos.y + '%';
        pin.dataset.id = String(loc.id);

        // Sanitize icon class to prevent XSS (only allow fa- prefixed identifiers)
        const safeIcon = (loc.icon && /^fa-[a-z0-9-]+$/.test(loc.icon)) ? loc.icon : 'fa-map-pin';
        pin.innerHTML = `
            <i class="fas ${safeIcon}"></i>
            <div class="spawn-pin-label">${escHtml(loc.label)}</div>
        `;

        pin.addEventListener('click', () => selectSpawnPin(loc.id));
        map.appendChild(pin);
    });
}

function selectSpawnPin(id) {
    selectedSpawnId = id;
    const loc = spawnLocations.find(l => l.id === id);

    // Update pin states
    document.querySelectorAll('.spawn-pin').forEach(p => {
        p.classList.toggle('active', p.dataset.id === String(id));
    });

    // Deselect last location
    document.getElementById('btnLastLocation').classList.remove('active');

    // Update info
    if (loc) {
        document.getElementById('spawnLocationName').textContent = loc.label.toUpperCase();
        const infoIcon = document.getElementById('spawnLocationInfo').querySelector('i');
        const infoSafeIcon = (loc.icon && /^fa-[a-z0-9-]+$/.test(loc.icon)) ? loc.icon : 'fa-map-pin';
        if (infoIcon) infoIcon.className = 'fas ' + infoSafeIcon;
        document.getElementById('spawnLocationInfo').classList.add('selected');

        // Enable spawn button
        document.getElementById('btnSpawn').classList.remove('disabled');
    }
}

// Last Location button
document.getElementById('btnLastLocation').addEventListener('click', () => {
    selectedSpawnId = 'last_location';

    // Deselect pins
    document.querySelectorAll('.spawn-pin').forEach(p => p.classList.remove('active'));

    // Highlight button
    document.getElementById('btnLastLocation').classList.add('active');

    // Update info
    document.getElementById('spawnLocationName').textContent = 'LAST LOCATION';
    const infoIcon = document.getElementById('spawnLocationInfo').querySelector('i');
    if (infoIcon) infoIcon.className = 'fas fa-history';
    document.getElementById('spawnLocationInfo').classList.add('selected');

    // Enable spawn
    document.getElementById('btnSpawn').classList.remove('disabled');
});

// Spawn button
document.getElementById('btnSpawn').addEventListener('click', () => {
    if (!selectedChar || !selectedSpawnId) return;
    if (document.getElementById('btnSpawn').classList.contains('disabled')) return;

    fetchNui('selectCharacter', {
        citizenid: selectedChar.citizenid,
        spawnLocation: selectedSpawnId,
    });

    closeSpawnSelector();
});

// ============================================================
// KEYBOARD SHORTCUTS
// ============================================================

document.addEventListener('keydown', (e) => {
    // ESC closes modals
    if (e.key === 'Escape') {
        if (!document.getElementById('spawnModal').classList.contains('hidden')) {
            closeSpawnSelector();
            return;
        }
        if (!document.getElementById('createModal').classList.contains('hidden')) {
            document.getElementById('btnCancelCreate').click();
            return;
        }
        if (!document.getElementById('deleteModal').classList.contains('hidden')) {
            document.getElementById('btnCancelDelete').click();
            return;
        }
    }

    // Enter confirms spawn/create/delete
    if (e.key === 'Enter') {
        if (!document.getElementById('spawnModal').classList.contains('hidden') &&
            !document.getElementById('btnSpawn').classList.contains('disabled')) {
            document.getElementById('btnSpawn').click();
            return;
        }
        if (!document.getElementById('createModal').classList.contains('hidden')) {
            document.getElementById('btnConfirmCreate').click();
            return;
        }
        if (!document.getElementById('deleteModal').classList.contains('hidden') &&
            !document.getElementById('btnConfirmDelete').classList.contains('disabled')) {
            document.getElementById('btnConfirmDelete').click();
            return;
        }
    }
});

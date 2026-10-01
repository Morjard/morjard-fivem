/* ============================================================
   MORJARD SPAWN SELECTOR — App Logic
   ============================================================ */

(function () {
    'use strict';

    // ---- STATE ----
    let selectedLocation = null;
    let locations = [];
    let currentCategory = 'all';
    let lastLocationEnabled = true;
    let isVisible = false;

    // ---- DOM REFS ----
    const spawnSelector = document.getElementById('spawnSelector');
    const mapPins = document.getElementById('mapPins');
    const locationList = document.getElementById('locationList');
    const locCount = document.getElementById('locCount');
    const selectedName = document.getElementById('selectedName');
    const locationInfo = document.getElementById('locationInfo');
    const infoIcon = document.getElementById('infoIcon');
    const infoName = document.getElementById('infoName');
    const infoDesc = document.getElementById('infoDesc');
    const btnSpawn = document.getElementById('btnSpawn');
    const btnSpawnText = document.getElementById('btnSpawnText');
    const btnLastLocation = document.getElementById('btnLastLocation');

    // ============================================================
    // NUI MESSAGE HANDLER
    // ============================================================

    window.addEventListener('message', function (event) {
        const data = event.data;

        switch (data.action) {
            case 'showSpawnSelector':
                locations = data.locations || [];
                lastLocationEnabled = data.enableLastLocation !== false;
                resetState();
                renderLocations();
                showSelector();
                break;

            case 'hideSpawnSelector':
                hideSelector();
                break;
        }
    });

    // ============================================================
    // RESET STATE
    // ============================================================

    function resetState() {
        selectedLocation = null;
        currentCategory = 'all';

        // Reset category buttons
        document.querySelectorAll('.cat-btn').forEach(function (b) {
            b.classList.remove('active');
        });
        var allBtn = document.querySelector('.cat-btn[data-cat="all"]');
        if (allBtn) allBtn.classList.add('active');

        // Reset UI
        selectedName.textContent = 'SELECT LOCATION';
        locationInfo.classList.remove('selected');
        infoName.textContent = 'SELECT A LOCATION';
        infoDesc.textContent = 'Click a pin or card to preview';
        infoIcon.className = 'fas fa-map-pin';
        btnSpawn.classList.add('disabled');
        btnSpawnText.textContent = 'SPAWN';
        btnLastLocation.classList.remove('active');

        // Show/hide last location button
        if (lastLocationEnabled) {
            btnLastLocation.classList.remove('hidden-btn');
        } else {
            btnLastLocation.classList.add('hidden-btn');
        }
    }

    // ============================================================
    // RENDER LOCATIONS
    // ============================================================

    function renderLocations() {
        mapPins.innerHTML = '';
        locationList.innerHTML = '';

        var filtered = currentCategory === 'all'
            ? locations
            : locations.filter(function (l) { return l.category === currentCategory; });

        filtered.forEach(function (loc, idx) {
            // Create map pin (diamond)
            var pin = createMapPin(loc, idx);
            mapPins.appendChild(pin);

            // Create sidebar card
            var card = createLocationCard(loc, idx);
            locationList.appendChild(card);
        });

        locCount.textContent = filtered.length;

        // Re-highlight selected if it exists in filtered set
        if (selectedLocation) {
            highlightSelected(selectedLocation.id);
        }
    }

    // ============================================================
    // CREATE MAP PIN
    // ============================================================

    function createMapPin(loc, idx) {
        var pin = document.createElement('div');
        pin.className = 'map-pin';
        pin.dataset.loc = loc.id;
        pin.style.top = loc.cssTop;
        pin.style.left = loc.cssLeft;
        pin.style.animation = 'pinAppear 0.4s ease ' + (idx * 0.08) + 's forwards';

        // Sanitize icon
        var safeIcon = sanitizeIcon(loc.icon);

        pin.innerHTML =
            '<div class="pin-diamond"><i class="fas fa-' + safeIcon + '"></i></div>' +
            '<div class="pin-pulse"></div>' +
            '<span class="pin-label">' + escapeHtml(loc.name) + '</span>';

        pin.addEventListener('click', function () {
            selectLocation(loc);
        });

        return pin;
    }

    // ============================================================
    // CREATE LOCATION CARD
    // ============================================================

    function createLocationCard(loc, idx) {
        var card = document.createElement('div');
        card.className = 'location-card';
        card.dataset.loc = loc.id;
        card.style.animation = 'fadeUp 0.3s ease ' + (idx * 0.05) + 's forwards';

        var safeIcon = sanitizeIcon(loc.icon);

        card.innerHTML =
            '<div class="loc-icon"><i class="fas fa-' + safeIcon + '"></i></div>' +
            '<div class="loc-info">' +
                '<span class="loc-name">' + escapeHtml(loc.name) + '</span>' +
                '<span class="loc-desc">' + escapeHtml(loc.description) + '</span>' +
                '<span class="loc-category">' + escapeHtml(loc.category) + '</span>' +
            '</div>' +
            '<div class="loc-arrow"><i class="fas fa-chevron-right"></i></div>';

        card.addEventListener('click', function () {
            selectLocation(loc);
        });

        return card;
    }

    // ============================================================
    // SELECT LOCATION
    // ============================================================

    function selectLocation(loc) {
        selectedLocation = loc;

        // Update topbar
        selectedName.textContent = loc.name;

        // Highlight elements
        highlightSelected(loc.id);

        // Deselect last location button
        btnLastLocation.classList.remove('active');

        // Update info panel
        locationInfo.classList.add('selected');
        infoName.textContent = loc.name;
        infoDesc.textContent = loc.description;
        var safeIcon = sanitizeIcon(loc.icon);
        infoIcon.className = 'fas fa-' + safeIcon;

        // Enable spawn button
        btnSpawn.classList.remove('disabled');
        btnSpawnText.textContent = 'SPAWN — ' + loc.name;

        // Trigger camera preview in game
        postNui('previewLocation', { location: loc.id });
    }

    function highlightSelected(locId) {
        // Pins
        document.querySelectorAll('.map-pin').forEach(function (p) {
            p.classList.toggle('selected', p.dataset.loc === locId);
        });

        // Cards
        document.querySelectorAll('.location-card').forEach(function (c) {
            c.classList.toggle('selected', c.dataset.loc === locId);
        });

        // Scroll selected card into view
        var selectedCard = document.querySelector('.location-card[data-loc="' + locId + '"]');
        if (selectedCard) {
            selectedCard.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }
    }

    // ============================================================
    // CATEGORY FILTER
    // ============================================================

    document.querySelectorAll('.cat-btn').forEach(function (btn) {
        btn.addEventListener('click', function () {
            document.querySelectorAll('.cat-btn').forEach(function (b) {
                b.classList.remove('active');
            });
            btn.classList.add('active');
            currentCategory = btn.dataset.cat;
            renderLocations();
        });
    });

    // ============================================================
    // SPAWN BUTTON
    // ============================================================

    btnSpawn.addEventListener('click', function () {
        if (!selectedLocation) return;
        if (btnSpawn.classList.contains('disabled')) return;

        postNui('spawn', { location: selectedLocation.id });
        hideSelector();
    });

    // ============================================================
    // LAST LOCATION BUTTON
    // ============================================================

    btnLastLocation.addEventListener('click', function () {
        // Deselect pins and cards
        document.querySelectorAll('.map-pin').forEach(function (p) {
            p.classList.remove('selected');
        });
        document.querySelectorAll('.location-card').forEach(function (c) {
            c.classList.remove('selected');
        });

        // Set as "selected" (special)
        selectedLocation = { id: 'last_location', name: 'LAST LOCATION' };
        btnLastLocation.classList.add('active');

        // Try to highlight the last_location card/pin if it exists
        highlightSelected('last_location');

        // Update UI
        selectedName.textContent = 'LAST LOCATION';
        locationInfo.classList.add('selected');
        infoName.textContent = 'LAST LOCATION';
        infoDesc.textContent = 'Return to where you left off';
        infoIcon.className = 'fas fa-clock-rotate-left';

        // Enable spawn button — but use special callback
        btnSpawn.classList.remove('disabled');
        btnSpawnText.textContent = 'SPAWN — LAST LOCATION';
    });

    // Override spawn click to handle last location separately
    var originalSpawnClick = btnSpawn.onclick;
    btnSpawn.addEventListener('click', function (e) {
        if (!selectedLocation) return;
        if (btnSpawn.classList.contains('disabled')) return;

        if (selectedLocation.id === 'last_location') {
            e.stopImmediatePropagation();
            postNui('lastLocation', {});
            hideSelector();
        }
    }, true); // Use capture phase to run before the other handler

    // ============================================================
    // KEYBOARD SHORTCUTS
    // ============================================================

    document.addEventListener('keydown', function (e) {
        if (!isVisible) return;

        // Enter = confirm spawn
        if (e.key === 'Enter') {
            if (selectedLocation && !btnSpawn.classList.contains('disabled')) {
                btnSpawn.click();
            }
        }

        // ESC is intentionally NOT handled — player must choose a spawn
    });

    // ============================================================
    // SHOW / HIDE
    // ============================================================

    function showSelector() {
        spawnSelector.classList.remove('hidden');
        isVisible = true;
    }

    function hideSelector() {
        spawnSelector.classList.add('hidden');
        isVisible = false;
        selectedLocation = null;
    }

    // ============================================================
    // NUI POST HELPER
    // ============================================================

    function postNui(endpoint, data) {
        // Use fetch (works in FiveM CEF)
        fetch('https://morjard-spawn-selector/' + endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        }).catch(function () {
            // Silently fail in dev/browser mode
        });
    }

    // ============================================================
    // UTILITIES
    // ============================================================

    function escapeHtml(str) {
        if (!str) return '';
        var div = document.createElement('div');
        div.appendChild(document.createTextNode(str));
        return div.innerHTML;
    }

    function sanitizeIcon(icon) {
        if (!icon) return 'map-pin';
        // Only allow alphanumeric and hyphens
        var clean = String(icon).replace(/[^a-z0-9-]/gi, '');
        return clean || 'map-pin';
    }

})();

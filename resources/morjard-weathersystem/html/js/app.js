// Morjard Weather System — app.js

let selectedZone = 1;
let selectedTimezone = 1;
let zones = [];
let weatherTypes = [];
let timezones = [];
let isSliderDragging = false;
let L = {}; // locale strings

// Icon mapping
const iconMap = {
    'sun':'fa-sun','cloud':'fa-cloud','cloud-rain':'fa-cloud-rain',
    'cloud-bolt':'fa-cloud-bolt','cloud-sun':'fa-cloud-sun',
    'smog':'fa-smog','snowflake':'fa-snowflake','wind':'fa-wind'
};

const zoneIcons = {
    'Los Santos City':'fa-city','Sandy Shores Desert':'fa-sun',
    'Paleto Bay':'fa-water','Grapeseed Area':'fa-wheat-awn','Mount Chiliad':'fa-mountain'
};

// ========================
// LOCALE
// ========================

const locales = {
    en: {
        feel:['FREEZING','VERY COLD','COLD','COOL','PLEASANT','WARM','HOT','SCORCHING'],
        envData:'ENV DATA', wind:'WIND', time:'TIME',
        noon:'NOON', midnight:'MIDNIGHT', dawn:'DAWN', morning:'MORNING',
        afternoon:'AFTERNOON', evening:'EVENING', night:'NIGHT',
        noEvent:'No active event', active:'Active: ',
    },
    cs: {
        feel:['SILNÝ MRÁZ','MRÁZ','STUDENÉ','CHLADNÉ','PŘÍJEMNÉ','TEPLÉ','HORKO','VEDRO'],
        envData:'ENV DATA', wind:'VÍTR', time:'ČAS',
        noon:'POLEDNE', midnight:'PŮLNOC', dawn:'SVÍTÁNÍ', morning:'DOPOLEDNE',
        afternoon:'ODPOLEDNE', evening:'VEČER', night:'NOC',
        noEvent:'Žádná aktivní událost', active:'Aktivní: ',
    },
    de: {
        feel:['EISIG','SEHR KALT','KALT','KÜHL','ANGENEHM','WARM','HEISS','GLUTHITZE'],
        envData:'ENV DATEN', wind:'WIND', time:'ZEIT',
        noon:'MITTAG', midnight:'MITTERNACHT', dawn:'DÄMMERUNG', morning:'MORGEN',
        afternoon:'NACHMITTAG', evening:'ABEND', night:'NACHT',
        noEvent:'Kein aktives Ereignis', active:'Aktiv: ',
    },
    fr: {
        feel:['GLACIAL','TRÈS FROID','FROID','FRAIS','AGRÉABLE','CHAUD','CHAUD','TORRIDE'],
        envData:'DONNÉES ENV', wind:'VENT', time:'HEURE',
        noon:'MIDI', midnight:'MINUIT', dawn:'AUBE', morning:'MATIN',
        afternoon:'APRÈS-MIDI', evening:'SOIR', night:'NUIT',
        noEvent:'Aucun événement actif', active:'Actif: ',
    },
    ru: {
        feel:['СИЛЬНЫЙ МОРОЗ','МОРОЗ','ХОЛОДНО','ПРОХЛАДНО','ПРИЯТНО','ТЕПЛО','ЖАРКО','ЗНОЙ'],
        envData:'ENV ДАННЫЕ', wind:'ВЕТЕР', time:'ВРЕМЯ',
        noon:'ПОЛДЕНЬ', midnight:'ПОЛНОЧЬ', dawn:'РАССВЕТ', morning:'УТРО',
        afternoon:'ДЕНЬ', evening:'ВЕЧЕР', night:'НОЧЬ',
        noEvent:'Нет активных событий', active:'Активно: ',
    },
    ua: {
        feel:['СИЛЬНИЙ МОРОЗ','МОРОЗ','ХОЛОДНО','ПРОХОЛОДНО','ПРИЄМНО','ТЕПЛО','СПЕКОТНО','НЕСТЕРПНА СПЕКА'],
        envData:'ENV ДАНІ', wind:'ВІТЕР', time:'ЧАС',
        noon:'ПОЛУДЕНЬ', midnight:'ПІВНІЧ', dawn:'СВІТАНОК', morning:'РАНОК',
        afternoon:'ДЕНЬ', evening:'ВЕЧІР', night:'НІЧ',
        noEvent:'Немає активних подій', active:'Активно: ',
    },
    ja: {
        feel:['極寒','とても寒い','寒い','涼しい','快適','暖かい','暑い','猛暑'],
        envData:'環境データ', wind:'風速', time:'時刻',
        noon:'正午', midnight:'深夜', dawn:'夜明け', morning:'午前',
        afternoon:'午後', evening:'夕方', night:'夜',
        noEvent:'アクティブなイベントなし', active:'アクティブ: ',
    },
    es: {
        feel:['HELADO','MUY FRÍO','FRÍO','FRESCO','AGRADABLE','CÁLIDO','CALIENTE','ABRASADOR'],
        envData:'DATOS ENV', wind:'VIENTO', time:'HORA',
        noon:'MEDIODÍA', midnight:'MEDIANOCHE', dawn:'AMANECER', morning:'MAÑANA',
        afternoon:'TARDE', evening:'NOCHE', night:'MADRUGADA',
        noEvent:'Ningún evento activo', active:'Activo: ',
    },
    it: {
        feel:['GELIDO','MOLTO FREDDO','FREDDO','FRESCO','PIACEVOLE','CALDO','MOLTO CALDO','TORRIDO'],
        envData:'DATI AMB', wind:'VENTO', time:'ORA',
        noon:'MEZZOGIORNO', midnight:'MEZZANOTTE', dawn:'ALBA', morning:'MATTINA',
        afternoon:'POMERIGGIO', evening:'SERA', night:'NOTTE',
        noEvent:'Nessun evento attivo', active:'Attivo: ',
    },
};

function setLocale(code) {
    L = locales[code] || locales['en'];
    // Update static labels
    $('#lblEnvData').text(L.envData);
    $('#lblWind').text(L.wind);
    $('#lblTime').text(L.time);
    $('#activeEventsText').text(L.noEvent);
}

function getTempFeel(temp) {
    const f = L.feel || locales.en.feel;
    if (temp <= -5)  return f[0];
    if (temp <= 2)   return f[1];
    if (temp <= 10)  return f[2];
    if (temp <= 18)  return f[3];
    if (temp <= 24)  return f[4];
    if (temp <= 30)  return f[5];
    if (temp <= 36)  return f[6];
    return f[7];
}

function getTempBarWidth(temp) {
    return Math.max(2, Math.min(100, ((temp + 15) / 55) * 100)) + '%';
}

// ========================
// NUI MESSAGES
// ========================

window.addEventListener('message', function(e) {
    const msg = e.data;
    switch(msg.action) {
        case 'show':         showWidget(); break;
        case 'hide':         hideWidget(); break;
        case 'update':       if(msg.locale) setLocale(msg.locale); updateWidget(msg.data); break;
        case 'openMenu':     openMenu(msg); break;
        case 'showAlert':    showAlert(msg.text); break;
        case 'playSiren':    playSiren(); break;
        case 'stopSiren':    stopSiren(); break;
        case 'hideAlert':    hideAlert(); break;
        case 'eventStarted': onEventStarted(msg.event); break;
        case 'eventStopped': onEventStopped(); break;
    }
});

function showWidget() { $('#weatherWidget').removeClass('hidden'); }
function hideWidget()  { $('#weatherWidget').addClass('hidden'); }

function updateWidget(data) {
    const ic = iconMap[data.weatherIcon] || 'fa-sun';
    $('#weatherIcon').attr('class', 'fas ' + ic);
    if (data.showZone) $('#zoneName').text((data.zone || '').toUpperCase());
    $('#weatherStatus').text(data.weather || '');

    if (data.showTemperature !== false) {
        const t = parseFloat(data.temperature);
        $('#temperature').text(Number.isInteger(t) ? t : t.toFixed(1));
        $('#tempBar').css('width', getTempBarWidth(t));
        $('#tempFeel').text(getTempFeel(t));
    }
    if (data.showWind !== false) $('#windSpeed').text(Math.round(data.windSpeed || 0));
    if (data.showTime !== false)  $('#time').text(data.time || '00:00');
}

// ========================
// SIREN AUDIO
// ========================
let sirenAudio = null;
let sirenTimeout = null;

function playSiren() {
    stopSiren();
    try {
        sirenAudio = new Audio('../sound/siren.mp3');
        sirenAudio.volume = 0.85;
        sirenAudio.play().catch(e => console.log('Siren play error:', e));
        // Auto-stop after 15 seconds (dont loop forever)
        sirenTimeout = setTimeout(() => stopSiren(), 15000);
    } catch(e) { console.log('Siren error:', e); }
}

function stopSiren() {
    if (sirenTimeout) { clearTimeout(sirenTimeout); sirenTimeout = null; }
    if (sirenAudio) {
        sirenAudio.pause();
        sirenAudio.currentTime = 0;
        sirenAudio = null;
    }
}

// Events that should trigger siren
// Siren only for tsunami and meteor shower
const SIREN_EVENTS = ['tsunami', 'meteor'];

function showAlert(text) {
    $('#widgetAlertText').text(text || 'WARNING');
    $('#widgetAlert').removeClass('hidden');
}
function hideAlert() { $('#widgetAlert').addClass('hidden'); }

function onEventStarted(name) {
    $('#activeEventsText').text((L.active || 'Active: ') + name);
    $('#activeEventBadge').removeClass('hidden');
    // Play siren for dangerous events
    if (SIREN_EVENTS.includes(name)) {
        playSiren();
    }
}
function onEventStopped() {
    $('#activeEventsText').text(L.noEvent || 'No active event');
    $('#activeEventBadge').addClass('hidden');
    hideAlert();
    stopSiren();
}

// ========================
// MENU OPEN
// ========================

function openMenu(data) {
    zones        = data.zones    || [];
    weatherTypes = data.weathers || [];
    timezones    = data.timezones || [];

    const locale = data.locale || 'en';
    setLocale(locale);

    // Update tab labels from Lua locale data (passed in msg)
    if (data.strings) {
        const s = data.strings;
        $('#tabWeather').text(s.menu_weather || 'WEATHER');
        $('#tabTime').text(s.menu_time || 'TIME');
        $('#tabEvents').text(s.menu_events || 'EVENTS');
        $('#tabRealtime').text(s.menu_realtime || 'REAL-TIME');
        $('#lblZones').text(s.menu_zones || 'ZONES');
        $('#lblWeatherType').text(s.menu_weather_type || 'WEATHER TYPE');
        $('#lblGameTime').text(s.menu_game_time || 'GAME TIME');
        $('#lblRtTitle').text(s.menu_realtime_title || 'REAL-TIME SYNC');
        $('#lblRtSub').text(s.menu_realtime_sub || '');
        $('#lblEventsIntro').text(s.menu_events_intro || '');
        $('#lblLiveSync').text(s.menu_live_sync || 'LIVE SYNC');
        $('#tzSearch').attr('placeholder', s.menu_search_tz || 'Search timezone...');
        $('#presetMidnight').text(s.preset_midnight || 'Midnight');
        $('#presetDawn').text(s.preset_dawn || 'Dawn');
        $('#presetNoon').text(s.preset_noon || 'Noon');
        $('#presetSunset').text(s.preset_sunset || 'Sunset');
        $('#presetNight').text(s.preset_night || 'Night');
    }

    buildEventCards(data.strings || {});
    buildZoneList();
    buildWeatherGrid();
    buildTimezoneGrid('');

    const ct = data.currentTime || {hour:12, minute:0};
    const total = ct.hour * 60 + ct.minute;
    $('#timeSlider').val(total);
    updateTimeDisplay(total);
    updateSliderIcon(total);

    $('#realTimeToggle').prop('checked', data.realTimeEnabled || false);
    selectedTimezone = data.realTimeTimezone || 1;

    $('#weatherMenu').removeClass('hidden');
}

// ========================
// EVENT CARDS (dynamic, localized)
// ========================

function buildEventCards(s) {
    const events = [
        { id:'tsunami',       icon:'fa-water',              cls:'ei-tsunami', danger:'extreme', nameKey:'ev_tsunami_name', descKey:'ev_tsunami_desc', tagKeys:['tag_extreme','WIND 80+','FLOOD'], tagClss:['red','',''] },
        { id:'earthquake',    icon:'fa-house-crack',         cls:'ei-quake',   danger:'high',    nameKey:'ev_quake_name',   descKey:'ev_quake_desc',   tagKeys:['tag_high','SHAKE','SOUND'],     tagClss:['orange','',''] },
        { id:'meteor',        icon:'fa-meteor',              cls:'ei-meteor',  danger:'medium',  nameKey:'ev_meteor_name',  descKey:'ev_meteor_desc',  tagKeys:['tag_medium','EXPLOSION','FIRE'], tagClss:['yellow','',''] },
        { id:'blackout',      icon:'fa-power-off',           cls:'ei-blackout',danger:'medium',  nameKey:'ev_blackout_name',descKey:'ev_blackout_desc',tagKeys:['tag_medium','DARK','5 MIN'],   tagClss:['yellow','',''] },
        { id:'sandstorm',     icon:'fa-wind',                cls:'ei-sand',    danger:'high',    nameKey:'ev_sand_name',    descKey:'ev_sand_desc',    tagKeys:['tag_high','WIND 60+','SMOG'],   tagClss:['orange','',''] },
        { id:'heatwave',      icon:'fa-temperature-arrow-up',cls:'ei-heat',    danger:'medium',  nameKey:'ev_heat_name',    descKey:'ev_heat_desc',    tagKeys:['tag_medium','40°C+','THIRST×5'],tagClss:['yellow','',''] },
        { id:'blizzard_event',   icon:'fa-snowflake',         cls:'ei-bliz',    danger:'high',    nameKey:'ev_blizzard_name', descKey:'ev_blizzard_desc', tagKeys:['tag_extreme','-15°C','ALL ZONES'],  tagClss:['red','',''] },
        { id:'fogpocalypse',     icon:'fa-smog',               cls:'ei-fog',     danger:'low',     nameKey:'ev_fog_name',      descKey:'ev_fog_desc',      tagKeys:['tag_low','FOG 1.0','ATMO'],        tagClss:['blue','',''] },
        { id:'zombie_apocalypse',icon:'fa-biohazard',          cls:'ei-zombie',  danger:'extreme', nameKey:'ev_zombie_name',   descKey:'ev_zombie_desc',   tagKeys:['tag_extreme','HORDES','ATTACK'],    tagClss:['red','',''] },
        { id:'stop_all',         icon:'fa-stop',               cls:'ei-stop',    danger:null,      nameKey:'ev_stop_name',     descKey:'ev_stop_desc',     tagKeys:['tag_reset'],                       tagClss:[''] },
    ];

    const $grid = $('#eventsGrid');
    $grid.empty();

    events.forEach(ev => {
        const name = s[ev.nameKey] || ev.nameKey;
        const desc = s[ev.descKey] || ev.descKey;
        const isStop = ev.id === 'stop_all';

        let tagsHtml = ev.tagKeys.map((tk, i) => {
            const label = s[tk] || tk;
            const cls   = ev.tagClss[i] || '';
            return `<span class="etag ${cls}">${label}</span>`;
        }).join('');

        const btnLabel = isStop
            ? (s['btn_stop']    || 'STOP ALL')
            : (s['btn_trigger'] || 'TRIGGER');

        const btnCls = isStop ? 'event-btn stop-btn' : 'event-btn';

        const dangerAttr = ev.danger ? `data-danger="${ev.danger}"` : '';

        $grid.append(`
            <div class="event-card" ${dangerAttr}>
                <div class="event-header">
                    <div class="event-icon-bg ${ev.cls}"><i class="fas ${ev.icon}"></i></div>
                    <div>
                        <div class="event-name">${name}</div>
                        <div class="event-tags">${tagsHtml}</div>
                    </div>
                </div>
                <div class="event-desc">${desc}</div>
                <button class="${btnCls}" onclick="triggerEvent('${ev.id}')">
                    <i class="fas ${isStop ? 'fa-stop' : 'fa-play'}"></i> ${btnLabel}
                </button>
            </div>
        `);
    });
}

function triggerEvent(eventType) {
    $.post('https://morjard-weathersystem/triggerEvent', JSON.stringify({event: eventType}));
}

// ========================
// ZONE LIST
// ========================

function buildZoneList() {
    const $list = $('#zoneGrid').empty();
    zones.forEach(zone => {
        const icon = zoneIcons[zone.name] || 'fa-map-marker-alt';
        const $el = $(`
            <div class="zone-item ${zone.id === selectedZone ? 'active' : ''}" data-zone="${zone.id}">
                <i class="fas ${icon}"></i>
                <div class="zone-item-name">${zone.name}</div>
                <div class="zone-item-weather">${zone.currentWeather}</div>
            </div>
        `);
        $el.on('click', function() { selectedZone = zone.id; buildZoneList(); buildWeatherGrid(); });
        $list.append($el);
    });
}

// ========================
// WEATHER GRID
// ========================

function buildWeatherGrid() {
    const $grid = $('#weatherGrid').empty();
    const active = (zones.find(z => z.id === selectedZone) || {}).currentWeather;
    weatherTypes.forEach(w => {
        const ic  = iconMap[w.icon] || 'fa-sun';
        const $el = $(`
            <div class="weather-card ${w.type === active ? 'active' : ''}" data-weather="${w.type}">
                <i class="fas ${ic}"></i>
                <span>${w.label}</span>
            </div>
        `);
        $el.on('click', function() { applyWeather(w.type); });
        $grid.append($el);
    });
}

function applyWeather(weatherType) {
    $.post('https://morjard-weathersystem/changeWeather', JSON.stringify({zoneId: selectedZone, weatherType}));
    const zone = zones.find(z => z.id === selectedZone);
    if (zone) zone.currentWeather = weatherType;
    buildZoneList();
    buildWeatherGrid();
}

// ========================
// TIMEZONE GRID
// ========================

function buildTimezoneGrid(filter) {
    const $grid = $('#timezoneGrid').empty();
    const f = (filter || '').toLowerCase();
    timezones.forEach(tz => {
        if (f && !tz.name.toLowerCase().includes(f) && !(tz.country||'').toLowerCase().includes(f)) return;
        const off = (tz.offset >= 0 ? '+' : '') + tz.offset;
        const $el = $(`
            <div class="timezone-card ${tz.offset === selectedTimezone ? 'active' : ''}">
                <i class="fas fa-${tz.icon}"></i>
                <div class="tz-name">${tz.name}</div>
                <div class="tz-offset">UTC ${off}</div>
                ${tz.dst ? '<div class="tz-dst">DST</div>' : ''}
            </div>
        `);
        $el.on('click', function() {
            selectedTimezone = tz.offset;
            buildTimezoneGrid(f);
            $.post('https://morjard-weathersystem/toggleRealTime', JSON.stringify({
                enabled: $('#realTimeToggle').is(':checked'),
                offset: selectedTimezone
            }));
        });
        $grid.append($el);
    });
}

// ========================
// TIME DISPLAY
// ========================

function updateTimeDisplay(minutes) {
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    $('#currentTimeDisplay').text(String(h).padStart(2,'0') + ':' + String(m).padStart(2,'0'));

    let label = L.night || 'NIGHT';
    if      (h >= 0  && h < 5)  label = L.midnight   || 'MIDNIGHT';
    else if (h >= 5  && h < 8)  label = L.dawn       || 'DAWN';
    else if (h >= 8  && h < 12) label = L.morning    || 'MORNING';
    else if (h >= 12 && h < 13) label = L.noon       || 'NOON';
    else if (h >= 13 && h < 17) label = L.afternoon  || 'AFTERNOON';
    else if (h >= 17 && h < 20) label = L.evening    || 'EVENING';
    else if (h >= 20)            label = L.night      || 'NIGHT';
    $('#timeOfDayLabel').text(label);
}

function updateSliderIcon(minutes) {
    const pct = (minutes / 1439) * 100;
    $('#sliderIcon').css('left', pct + '%');
    const h = Math.floor(minutes / 60);
    $('#sliderIcon i').attr('class', (h >= 6 && h < 20) ? 'fas fa-sun' : 'fas fa-moon');
}

// ========================
// DOCUMENT READY
// ========================

$(document).ready(function() {
    // Tabs
    $('.tab-nav').on('click', '.tab-btn', function() {
        const tab = $(this).data('tab');
        $('.tab-btn').removeClass('active');
        $('.tab-content').removeClass('active');
        $(this).addClass('active');
        $('#tab-' + tab).addClass('active');
    });

    // Close
    function closeMenu() {
        $('#weatherMenu').addClass('hidden');
        $.post('https://morjard-weathersystem/closeMenu', JSON.stringify({}));
    }
    $('#closeMenuBtn').on('click', closeMenu);
    $(document).on('keydown', e => { if (e.key === 'Escape' && !$('#weatherMenu').hasClass('hidden')) closeMenu(); });

    // Slider
    $('#timeSlider').on('mousedown touchstart', () => isSliderDragging = true);
    $('#timeSlider').on('input', function() {
        if (!isSliderDragging) return;
        const min = parseInt($(this).val());
        updateTimeDisplay(min);
        updateSliderIcon(min);
        $.post('https://morjard-weathersystem/realtimeTimeChange', JSON.stringify({hour: Math.floor(min/60), minute: min%60}));
    });
    $(document).on('mouseup touchend', function() {
        if (!isSliderDragging) return;
        isSliderDragging = false;
        const min = parseInt($('#timeSlider').val());
        $.post('https://morjard-weathersystem/changeTime', JSON.stringify({hour: Math.floor(min/60), minute: min%60}));
    });

    // Presets
    $('.time-presets').on('click', '.preset-btn', function() {
        const min = parseInt($(this).data('time'));
        $('#timeSlider').val(min);
        updateTimeDisplay(min);
        updateSliderIcon(min);
        $.post('https://morjard-weathersystem/changeTime', JSON.stringify({hour: Math.floor(min/60), minute: min%60}));
    });

    // Realtime toggle
    $('#realTimeToggle').on('change', function() {
        $.post('https://morjard-weathersystem/toggleRealTime', JSON.stringify({
            enabled: $(this).is(':checked'),
            offset: selectedTimezone
        }));
    });

    // TZ search
    $('#tzSearch').on('input', function() { buildTimezoneGrid($(this).val()); });

    // Init locale
    setLocale('en');
});

// ============================================================
// PLAYER TABLET UI
// ============================================================

let tabletOpen       = false;
let tabletWidgetOn   = true;   // stav widget toggle
let tabletZonesData  = [];     // data zón pro mapu
let tabletLocale     = 'cs';
let tabletActiveEvent= null;

// Texty pro tablet dle jazyka
const tabletLang = {
    cs: {
        overview:'PŘEHLED', zones:'MAPA', events:'UDÁLOSTI', settings:'NASTAVENÍ',
        noEvent:'Žádná aktivní událost', activeEvent:'AKTIVNÍ UDÁLOST',
        eventDesc:'Událost právě probíhá. Říď se pokyny vedení serveru.',
        widgetLabel:'Widget počasí', widgetSub:'Zobrazit/skrýt HUD v rohu obrazovky',
        displayTitle:'ZOBRAZENÍ', evtHeader:'Přírodní a meteorologické události',
        zonesHeader:'PŘEHLED POČASÍ DLE ZÓN', currentZone:'AKTUÁLNÍ',
        temp:'TEPLOTA', zone:'ZÓNA', wind:'VÍTR', time:'ČAS',
    },
    en: {
        overview:'OVERVIEW', zones:'MAP', events:'EVENTS', settings:'SETTINGS',
        noEvent:'No active event', activeEvent:'ACTIVE EVENT',
        eventDesc:'Event is in progress. Follow server instructions.',
        widgetLabel:'Weather Widget', widgetSub:'Show/hide HUD in screen corner',
        displayTitle:'DISPLAY', evtHeader:'Natural and meteorological events',
        zonesHeader:'WEATHER BY ZONE', currentZone:'CURRENT',
        temp:'TEMP', zone:'ZONE', wind:'WIND', time:'TIME',
    },
};

function getTL(key) {
    const t = tabletLang[tabletLocale] || tabletLang['en'];
    return t[key] || tabletLang['en'][key] || key;
}

// Nastav texty dle jazyka
function tabletSetLocale(locale) {
    tabletLocale = locale || 'cs';
    $('#tnav_overview').text(getTL('overview'));
    $('#tnav_zones').text(getTL('zones'));
    $('#tnav_events').text(getTL('events'));
    $('#tnav_settings').text(getTL('settings'));
    $('#tov-lbl-noEvent').text(getTL('noEvent'));
    $('#tevt-lbl-noEvent').text(getTL('noEvent'));
    $('#tsett-display-title').text(getTL('displayTitle'));
    $('#tsett-widget-label').text(getTL('widgetLabel'));
    $('#tsett-widget-sub').text(getTL('widgetSub'));
    $('#tevt-hdr').text(getTL('evtHeader'));
    $('#tz-hdr').text(getTL('zonesHeader'));
    $('#tov-lbl-wind').text(getTL('wind'));
    $('#tov-lbl-time').text(getTL('time'));
    $('#tov-lbl-temp').text(getTL('temp'));
    $('#tov-lbl-zone').text(getTL('zone'));
}

// Otevři tablet
function openPlayerTablet(data) {
    tabletOpen = true;
    tabletSetLocale(data.locale || 'cs');
    tabletZonesData = data.zones || [];

    // Aktualizuj přehled
    if (data.weather) tabletUpdateOverview(data.weather);

    // Render zóny
    tabletRenderZones(data.zones || [], data.currentZone);

    // Event stav
    tabletUpdateEvent(tabletActiveEvent);

    // Widget toggle stav
    $('#tabletWidgetToggle').prop('checked', tabletWidgetOn);

    // Čas v status baru
    if (data.time) {
        $('#tabletStatusTime').text(data.time);
    }

    $('#playerTablet').removeClass('hidden');

    // Aktivuj první tab
    tabletSwitchTab('overview');
}

function closePlayerTablet() {
    tabletOpen = false;
    $('#playerTablet').addClass('hidden');
    // Pošli zpátky do Lua
    fetch(`https://${GetParentResourceName()}/closePlayerTablet`, {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({})
    }).catch(() => {});
}

// Switch tab
function tabletSwitchTab(tabId) {
    $('.tablet-nav-btn').removeClass('active');
    $('.tablet-tab').removeClass('active');
    $(`.tablet-nav-btn[data-ttab="${tabId}"]`).addClass('active');
    $(`#ttab-${tabId}`).addClass('active');
}

// Aktualizuj přehled
function tabletUpdateOverview(data) {
    const ic = iconMap[data.weatherIcon] || 'fa-sun';
    $('#tov-icon').attr('class', 'fas ' + ic);
    $('#tov-zone').text((data.zone || '').toUpperCase());
    $('#tov-weather').text(data.weather || '');

    const t = parseFloat(data.temperature || 20);
    $('#tov-temp').text(Number.isInteger(t) ? t : t.toFixed(1));
    $('#tov-temp2').text(Number.isInteger(t) ? t : t.toFixed(1));
    $('#tov-feel').text(getTempFeel(t));
    $('#tov-wind').text(Math.round(data.windSpeed || 0));
    if (data.time) {
        $('#tov-time').text(data.time);
        $('#tabletStatusTime').text(data.time);
    }

    // Zkrácený název zóny
    const zn = data.zone || '';
    const parts = zn.split(' ');
    $('#tov-zone-short').text(parts.map(w => w[0]).join('').substring(0,4).toUpperCase() || 'LS');

    // Popis počasí
    const descs = {
        'EXTRASUNNY':'Extrémně slunečno', 'CLEAR':'Jasno, slunečno',
        'CLOUDS':'Oblačno', 'OVERCAST':'Zataženo',
        'RAIN':'Déšť', 'THUNDER':'Bouřka s blesky',
        'CLEARING':'Probíhá vyjasnění', 'FOGGY':'Hustá mlha',
        'SMOG':'Smog, snížená viditelnost', 'SNOW':'Sněžení',
        'BLIZZARD':'Vánice, silný mráz', 'SNOWLIGHT':'Lehké sněžení',
        'XMAS':'Vánoční sníh', 'HALLOWEEN':'Písečná bouře',
        'NEUTRAL':'Stabilní počasí',
    };
    const wType = data.weatherType || '';
    $('#tov-desc').text(descs[wType] || data.weather || '');
}

// Render zón
function tabletRenderZones(zones, currentZoneId) {
    const $list = $('#tzZoneList').empty();

    if (!zones || zones.length === 0) {
        $list.html('<div style="padding:30px;text-align:center;color:rgba(255,255,255,0.15);font-size:12px;">Načítám data zón...</div>');
        return;
    }

    const wIcons = {
        'EXTRASUNNY':'fa-sun','CLEAR':'fa-sun','CLOUDS':'fa-cloud',
        'OVERCAST':'fa-cloud','RAIN':'fa-cloud-rain','THUNDER':'fa-cloud-bolt',
        'CLEARING':'fa-cloud-sun','FOGGY':'fa-smog','SMOG':'fa-smog',
        'SNOW':'fa-snowflake','BLIZZARD':'fa-wind','SNOWLIGHT':'fa-snowflake',
        'XMAS':'fa-snowflake','HALLOWEEN':'fa-smog','NEUTRAL':'fa-cloud',
    };

    zones.forEach((z, i) => {
        const isCurrent = (i + 1) === currentZoneId;
        const icon = wIcons[z.weather] || 'fa-sun';
        const mapIcon = zoneIcons[z.name] || 'fa-map-marker-alt';

        let html = `
        <div class="tz-zone-card ${isCurrent ? 'current' : ''}">
            <div class="tz-zone-icon"><i class="fas ${mapIcon}"></i></div>
            <div class="tz-zone-info">
                <div class="tz-zone-name">${z.name}</div>
                <div class="tz-zone-weather"><i class="fas ${icon}" style="margin-right:5px;font-size:11px;opacity:0.7;"></i>${z.weather || 'N/A'}</div>
                ${z.description ? `<div class="tz-zone-desc">${z.description}</div>` : ''}
            </div>
            <div class="tz-zone-temp">${Math.round(z.temperature || 0)}<sup>°C</sup></div>
            ${isCurrent ? `<div class="tz-zone-badge">${getTL('currentZone')}</div>` : ''}
        </div>`;
        $list.append(html);
    });
}

// Event stav pro tablet
function tabletUpdateEvent(eventType) {
    tabletActiveEvent = eventType;

    const eventIcons = {
        'tsunami':'fa-water', 'earthquake':'fa-house-crack',
        'meteor':'fa-meteor', 'blackout':'fa-bolt',
        'sandstorm':'fa-wind', 'heatwave':'fa-temperature-high',
        'blizzard_event':'fa-snowflake', 'fogpocalypse':'fa-smog',
        'zombie_apocalypse':'fa-biohazard',
    };
    const eventNames = {
        'tsunami':'CUNAMI', 'earthquake':'ZEMĚTŘESENÍ',
        'meteor':'METEORICKÝ DÉŠŤ', 'blackout':'BLACKOUT',
        'sandstorm':'PÍSEČNÁ BOUŘE', 'heatwave':'VLNA VEDER',
        'blizzard_event':'SNĚHOVÁ BOUŘE', 'fogpocalypse':'APOKALYPTICKÁ MLHA',
        'zombie_apocalypse':'ZOMBIE APOKALYPSA',
    };

    if (eventType && eventType !== 'stop_all') {
        // Overview banner
        $('#tov-event-banner').removeClass('hidden');
        $('#tov-no-event').addClass('hidden');
        $('#tov-event-name').text(eventNames[eventType] || eventType.toUpperCase());

        // Events tab
        $('#tevt-active-block').removeClass('hidden');
        $('#tevt-no-event-block').addClass('hidden');
        const icon = eventIcons[eventType] || 'fa-bolt';
        $('#tevt-active-icon').html(`<i class="fas ${icon}"></i>`);
        $('#tevt-active-name').text(eventNames[eventType] || eventType.toUpperCase());
        $('#tevt-active-tag').text(getTL('activeEvent'));
        $('#tevt-active-desc').text(getTL('eventDesc'));

        // Badge na nav
        $('#tabletEventBadge').removeClass('hidden');
    } else {
        $('#tov-event-banner').addClass('hidden');
        $('#tov-no-event').removeClass('hidden');
        $('#tevt-active-block').addClass('hidden');
        $('#tevt-no-event-block').removeClass('hidden');
        $('#tabletEventBadge').addClass('hidden');
    }
}

// NUI message handler pro tablet
window.addEventListener('message', function(e) {
    const msg = e.data;
    if (msg.action === 'openPlayerTablet') {
        openPlayerTablet(msg);
    }
    if (msg.action === 'closePlayerTablet') {
        closePlayerTablet();
    }
    // Aktualizuj čas v tablet status baru živě
    if (msg.action === 'update' && msg.data && msg.data.time && tabletOpen) {
        $('#tabletStatusTime').text(msg.data.time);
        if (msg.data) {
            tabletUpdateOverview(msg.data);
        }
    }
    // Sync event do tabletu
    if (msg.action === 'eventStarted') {
        tabletUpdateEvent(msg.event);
    }
    if (msg.action === 'eventStopped') {
        tabletUpdateEvent(null);
    }
});

// Kliknutí na nav tlačítka tabletu
$(document).on('click', '.tablet-nav-btn', function() {
    const tab = $(this).data('ttab');
    tabletSwitchTab(tab);
});

// Zavření tabletu — home button
$(document).on('click', '#tabletCloseBtn', function() {
    closePlayerTablet();
});

// Widget toggle
$(document).on('change', '#tabletWidgetToggle', function() {
    tabletWidgetOn = $(this).is(':checked');
    if (tabletWidgetOn) {
        showWidget();
    } else {
        hideWidget();
    }
    // Pošli do Lua
    fetch(`https://${GetParentResourceName()}/tabletWidgetToggle`, {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ enabled: tabletWidgetOn })
    }).catch(() => {});
});

// ESC pro zavření
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && tabletOpen) {
        closePlayerTablet();
    }
});

// ── ZOMBIE SOUND PLAYER ──────────────────────────────────────────────────────
let zombieAudio = null;

window.addEventListener('message', function(e) {
    const d = e.data;
    if (!d || !d.action) return;

    if (d.action === 'playZombieSound' && d.file) {
        if (zombieAudio) { zombieAudio.pause(); zombieAudio = null; }
        zombieAudio = new Audio(`../${d.file}`);
        zombieAudio.volume = 0.65;
        zombieAudio.play().catch(() => {});
    }
    if (d.action === 'stopZombieSound') {
        if (zombieAudio) { zombieAudio.pause(); zombieAudio.currentTime = 0; zombieAudio = null; }
    }
});


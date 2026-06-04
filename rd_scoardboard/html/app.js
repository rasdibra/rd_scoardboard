const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rd_scoardboard';

const defaultLocale = {
    leftPage: 'Faqja majtas',
    playersOnline: 'Lojtarët Online',
    scoreboardTitle: 'RD Scoardboard',
    updated: 'Përditësuar',
    page: 'Faqe',
    online: 'online',
    back: '‹ Mbrapa',
    next: 'Para ›',
    close: 'Mbyll',
    refresh: 'Rifresko',
    emptySlot: 'Vend bosh',
    emptySlotDescription: 'Nuk ka lojtar në këtë rresht',
    id: 'ID',
    discord: 'Discord',
    noDiscord: 'Pa Discord',
    playtime: 'Playtime',
    job: 'Job',
    citizen: 'Qytetar',
    noCharacter: 'Pa character',
    milliseconds: 'ms'
};

const state = {
    visible: false,
    mode: 'open',
    language: 'albanian',
    locale: { ...defaultLocale },
    serverName: 'Eagle County RP',
    players: [],
    count: 0,
    max: 48,
    updated: '--:--',
    perPage: 5,
    spread: 0,
    showJobs: true,
    showPing: true,
    showDiscord: true,
    showPlaytime: true,
    refreshMs: 7000,
    refreshTimer: null
};

const $ = (id) => document.getElementById(id);

const ui = {
    scoreboard: $('scoreboard'),
    openBook: $('openBook'),
    closeBtn: $('closeBtn'),
    refreshBtn: $('refreshBtn'),
    prevBtn: $('prevBtn'),
    nextBtn: $('nextBtn'),
    pageInfo: $('pageInfo'),
    onlineCount: $('onlineCount'),
    leftList: $('leftList'),
    rightList: $('rightList'),
    leftPageNum: $('leftPageNum'),
    rightPageNum: $('rightPageNum'),
    updatedAt: $('updatedAt'),
    serverNameLeft: $('serverNameLeft'),
    serverNameRight: $('serverNameRight'),
    leftPageLabel: $('leftPageLabel'),
    playersOnlineTitle: $('playersOnlineTitle'),
    scoreboardTitle: $('scoreboardTitle')
};

function postNui(eventName, data = {}) {
    return fetch(`https://${resourceName}/${eventName}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function setText(node, value) {
    if (node) node.textContent = value == null ? '' : String(value);
}

function t(key, fallback = '') {
    const value = state.locale && state.locale[key];
    if (value == null || value === '') return fallback || defaultLocale[key] || key;
    return String(value);
}

function safeText(value, fallback = '—') {
    const text = String(value == null ? '' : value).trim();
    return text.length ? text : fallback;
}

function safeCssUrl(value) {
    const url = String(value || '').trim();
    if (!url) return '';
    if (!/^https?:\/\//i.test(url) && !/^nui:\/\//i.test(url) && !/^img\//i.test(url)) return '';
    return url.replace(/["'()\\]/g, '');
}

function showOpenBook() {
    state.mode = 'open';
    ui.scoreboard.classList.remove('hidden');
    ui.openBook.classList.remove('hidden');
    postNui('requestPlayers');
    startRefreshLoop();
    renderPlayers();
}

function hideAll() {
    state.visible = false;
    state.mode = 'closed';
    ui.scoreboard.classList.add('hidden');
    ui.openBook.classList.add('hidden');
    stopRefreshLoop();
}

function startRefreshLoop() {
    stopRefreshLoop();
    const delay = Number(state.refreshMs) || 7000;
    state.refreshTimer = setInterval(() => {
        if (state.visible && state.mode === 'open') postNui('requestPlayers');
    }, Math.max(2500, delay));
}

function stopRefreshLoop() {
    if (state.refreshTimer) {
        clearInterval(state.refreshTimer);
        state.refreshTimer = null;
    }
}

function setupStaticText() {
    document.documentElement.lang = state.language === 'english' ? 'en' : 'sq';
    setText(ui.serverNameLeft, state.serverName);
    setText(ui.serverNameRight, state.serverName);
    setText(ui.leftPageLabel, t('leftPage'));
    setText(ui.playersOnlineTitle, t('playersOnline'));
    setText(ui.scoreboardTitle, t('scoreboardTitle'));
    setText(ui.prevBtn, t('back'));
    setText(ui.nextBtn, t('next'));
    if (ui.closeBtn) ui.closeBtn.title = t('close');
    if (ui.refreshBtn) ui.refreshBtn.title = t('refresh');
}

function totalSpreads() {
    return Math.max(1, Math.ceil(state.players.length / (state.perPage * 2)));
}

function clampSpread() {
    const total = totalSpreads();
    if (state.spread > total - 1) state.spread = total - 1;
    if (state.spread < 0) state.spread = 0;
}

function addMetaLine(parent, items, extraClass = '') {
    const line = document.createElement('div');
    line.className = `player-meta-line${extraClass ? ` ${extraClass}` : ''}`;

    items.filter(Boolean).forEach((item) => {
        const chip = document.createElement('span');
        chip.className = `player-chip${item.full ? ' full-chip' : ''}`;
        chip.title = `${item.label}: ${item.value}`;

        const label = document.createElement('b');
        label.textContent = `${item.label}: `;

        const value = document.createElement('span');
        value.textContent = item.value;

        chip.appendChild(label);
        chip.appendChild(value);
        line.appendChild(chip);
    });

    parent.appendChild(line);
}

function createPlayerRow(player, empty = false) {
    const row = document.createElement('div');
    row.className = `player-row${empty ? ' empty' : ''}${player.isFake ? ' fake-player' : ''}`;

    const id = document.createElement('div');
    id.className = 'player-id';

    if (empty) {
        const dash = document.createElement('span');
        dash.textContent = '—';
        id.appendChild(dash);
    } else {
        const avatar = safeCssUrl(player.steamAvatar);
        if (avatar) {
            id.classList.add('has-avatar');
            id.style.backgroundImage = `linear-gradient(rgba(0,0,0,0.25), rgba(0,0,0,0.42)), url("${avatar}")`;
        }

        const small = document.createElement('small');
        small.textContent = t('id', 'ID');
        const value = document.createElement('span');
        value.textContent = player.id;
        id.appendChild(small);
        id.appendChild(value);
    }

    const main = document.createElement('div');
    main.className = 'player-main';

    const name = document.createElement('div');
    name.className = 'player-name';
    name.textContent = empty ? t('emptySlot') : safeText(player.character || player.characterName, t('noCharacter'));

    if (empty) {
        const sub = document.createElement('div');
        sub.className = 'player-sub';
        sub.textContent = t('emptySlotDescription');
        main.appendChild(name);
        main.appendChild(sub);
    } else {
        const jobText = state.showJobs && player.job ? `${player.job}${player.grade ? ` • ${player.grade}` : ''}` : t('citizen');

        main.appendChild(name);
        if (state.showDiscord) {
            addMetaLine(main, [
                { label: t('discord'), value: safeText(player.discordName, t('noDiscord')), full: true }
            ], 'discord-line');
        }
        addMetaLine(main, [
            state.showPlaytime ? { label: t('playtime'), value: safeText(player.playtime, '0m') } : null,
            state.showJobs ? { label: t('job'), value: jobText } : null
        ]);
    }

    const ping = document.createElement('div');
    ping.className = 'player-ping';
    ping.textContent = empty ? '' : (state.showPing ? `${player.ping || 0}${t('milliseconds', 'ms')}` : t('online'));

    row.appendChild(id);
    row.appendChild(main);
    row.appendChild(ping);
    return row;
}

function renderList(container, players) {
    container.textContent = '';
    const fragment = document.createDocumentFragment();
    for (let i = 0; i < state.perPage; i += 1) {
        const player = players[i];
        fragment.appendChild(createPlayerRow(player || {}, !player));
    }
    container.appendChild(fragment);
}

function renderPlayers() {
    clampSpread();

    const perSpread = state.perPage * 2;
    const start = state.spread * perSpread;
    const leftPlayers = state.players.slice(start, start + state.perPage);
    const rightPlayers = state.players.slice(start + state.perPage, start + perSpread);

    renderList(ui.leftList, leftPlayers);
    renderList(ui.rightList, rightPlayers);

    const leftPage = state.spread * 2 + 1;
    const rightPage = leftPage + 1;
    const realPageCount = Math.ceil(Math.max(state.players.length, 1) / state.perPage);
    const pageCount = Math.max(2, Math.ceil(realPageCount / 2) * 2);
    const pageLabel = t('page');

    setText(ui.leftPageNum, `${pageLabel} ${leftPage}`);
    setText(ui.rightPageNum, `${pageLabel} ${rightPage}`);
    setText(ui.pageInfo, `${pageLabel} ${leftPage}-${rightPage} / ${pageCount}`);
    setText(ui.onlineCount, `${state.count}/${state.max} ${t('online')}`);
    setText(ui.updatedAt, `${t('updated')} ${state.updated}`);

    ui.prevBtn.disabled = state.spread <= 0;
    ui.nextBtn.disabled = state.spread >= totalSpreads() - 1;
}

function openFromPayload(data) {
    state.visible = true;
    state.language = data.language || state.language;
    state.locale = { ...defaultLocale, ...(data.locale || {}) };
    state.serverName = data.serverName || state.serverName;
    state.perPage = Number(data.playersPerPage) || 5;
    state.refreshMs = Number(data.refreshMs) || 7000;
    state.showJobs = data.showJobs !== false;
    state.showPing = data.showPing !== false;
    state.showDiscord = data.showDiscord !== false;
    state.showPlaytime = data.showPlaytime !== false;
    state.players = [];
    state.count = 0;
    state.updated = '--:--';
    state.spread = 0;

    setupStaticText();
    showOpenBook();
}

function applyPlayers(payload) {
    if (!payload) return;
    state.players = Array.isArray(payload.players) ? payload.players : [];
    state.count = Number(payload.count) || state.players.length;
    state.max = Number(payload.max) || 48;
    state.updated = payload.updated || '--:--';
    if (state.visible && state.mode === 'open') renderPlayers();
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') openFromPayload(data);
    if (data.action === 'hide') hideAll();
    if (data.action === 'players') applyPlayers(data.payload);
});

ui.closeBtn.addEventListener('click', () => postNui('close'));
ui.refreshBtn.addEventListener('click', () => postNui('requestPlayers'));

ui.prevBtn.addEventListener('click', () => {
    if (state.spread > 0) {
        state.spread -= 1;
        renderPlayers();
    }
});

ui.nextBtn.addEventListener('click', () => {
    if (state.spread < totalSpreads() - 1) {
        state.spread += 1;
        renderPlayers();
    }
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') postNui('close');
    if (event.key && event.key.toLowerCase() === 'z') postNui('close');
});

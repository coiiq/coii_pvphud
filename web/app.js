(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const native = typeof GetParentResourceName === 'function';
  const preview = !native && new URLSearchParams(location.search).has('preview');
  const number = (value, fallback = 0) => Number.isFinite(Number(value)) ? Number(value) : fallback;
  const clamp = (value, max = 100) => Math.min(max, Math.max(0, number(value)));
  const whole = (value) => Math.max(0, Math.floor(number(value)));
  const integers = new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 });
  const state = {
    currency: '$', unit: 'kmh', scale: .85, selected: 0, player: {},
    sections: { info: true, status: true, weapon: true, slots: true, vehicle: true, killstreak: true },
    weapon: { armed: false }, vehicle: { active: false }, killstreak: { count: 0 },
  };
  let streakAnimationTimer;

  function icon(name, viewBox = '0 0 100 50') {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', viewBox);
    const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
    use.setAttribute('href', `icons.svg#${name}`);
    svg.append(use);
    return svg;
  }

  function fallbackFor(item) {
    const name = String(item.name || '').toLowerCase();
    if (item.empty) return 'empty';
    if (/pistol|revolver/.test(name)) return 'pistol';
    if (/grenade|bomb|molotov/.test(name)) return 'grenade';
    if (/weapon_/.test(name)) return 'rifle';
    if (/bandage|medikit|firstaid/.test(name)) return 'bandage';
    if (/armo[u]?r|plate/.test(name)) return 'vest';
    return 'box';
  }

  function setImage(img, fallback, source) {
    const valid = typeof source === 'string' && /^https?:\/\//i.test(source);
    const url = valid ? source : '';
    if (img.dataset.source === url) return;
    img.dataset.source = url;
    img.hidden = true;
    fallback.removeAttribute('hidden');
    if (!url) { img.removeAttribute('src'); return; }
    img.onload = () => { img.hidden = false; fallback.setAttribute('hidden', ''); };
    img.onerror = () => { img.hidden = true; fallback.removeAttribute('hidden'); };
    img.src = url;
  }

  const slots = Array.from({ length: 5 }, (_, index) => {
    const el = document.createElement('div');
    el.className = 'slot empty';
    const key = document.createElement('span'); key.className = 'slot-key';
    const count = document.createElement('span'); count.className = 'slot-count';
    const art = document.createElement('div'); art.className = 'slot-art';
    const fallback = icon('empty');
    const img = document.createElement('img'); img.alt = ''; img.hidden = true;
    art.append(fallback, img);
    const label = document.createElement('span'); label.className = 'slot-label';
    el.append(key, count, art, label);
    $('slots').append(el);
    return { el, key, count, fallback, img, label, slot: index + 1, empty: true };
  });

  function selectSlot() {
    slots.forEach(({ el, slot, empty }) => {
      const active = !empty && slot === state.selected;
      el.classList.toggle('active', active);
      el.setAttribute('aria-current', String(active));
    });
  }

  function renderSlots(data) {
    if (!Array.isArray(data)) return;
    slots.forEach((view, index) => {
      const item = data[index] || { empty: true };
      view.slot = number(item.slot, index + 1);
      view.empty = item.empty !== false;
      view.el.classList.toggle('empty', view.empty);
      view.key.textContent = String(item.key || index + 1).padStart(2, '0');
      view.count.textContent = view.empty ? '' : `×${String(whole(item.count)).padStart(2, '0')}`;
      view.label.textContent = view.empty ? 'Empty' : String(item.label || item.name || 'Item');
      view.el.setAttribute('aria-label', `Slot ${view.key.textContent}: ${view.label.textContent}${view.empty ? '' : `, ${whole(item.count)}`}`);
      const kind = fallbackFor(item);
      view.fallback.firstElementChild.setAttribute('href', `icons.svg#${kind}`);
      setImage(view.img, view.fallback, view.empty ? '' : item.image);
    });
    selectSlot();
  }

  function money(amount) { return state.currency + integers.format(number(amount)); }
  function renderPlayer(data) {
    state.player = data;
    $('job').textContent = data.job || 'Civilian';
    const grade = String(data.grade || '');
    $('grade').textContent = grade;
    $('job-separator').hidden = !grade;
    $('cash').textContent = money(data.cash);
    $('bank').textContent = money(data.bank);
    $('safe').textContent = data.safe?.available ? money(data.safe.amount) : '—';
    $('safe').title = data.safe?.available ? 'Job society account' : 'Job safe unavailable';
  }

  function renderVitals(data) {
    ['health', 'armor'].forEach((kind) => {
      const value = Math.round(clamp(data[kind]));
      $(`${kind}-value`).textContent = value;
      $(`${kind}-fill`).style.transform = `scaleX(${value / 100})`;
      $(`${kind}-meter`).setAttribute('aria-valuenow', value);
    });
  }

  function renderWeapon(data) {
    state.weapon = data;
    const armed = data.armed === true;
    $('combat-summary').classList.toggle('is-armed', armed && state.sections.weapon);
    $('weapon-panel').setAttribute('aria-hidden', String(!armed || !state.sections.weapon));
    state.selected = armed ? number(data.slot) : 0;
    selectSlot();
    // Keep the previous weapon intact while it fades; no unarmed placeholder.
    if (!armed) return;
    $('weapon-name').textContent = data.label || 'Weapon';
    $('weapon-status').textContent = data.reloading ? 'RELOADING' : 'EQUIPPED';
    $('ammo').hidden = data.showAmmo === false;
    $('clip').textContent = String(whole(data.clip)).padStart(2, '0');
    $('reserve').textContent = String(whole(data.reserve)).padStart(3, '0');
    $('weapon-fallback').firstElementChild.setAttribute('href', `icons.svg#${fallbackFor({ name: data.label?.toLowerCase().includes('pistol') ? 'weapon_pistol' : 'weapon_rifle' })}`);
    setImage($('weapon-image'), $('weapon-fallback'), data.image);
  }

  function renderVehicle(data) {
    state.vehicle = data;
    $('vehicle').hidden = !state.sections.vehicle || !data.active;
    if (!data.active) return;
    $('speed').textContent = String(Math.min(999, whole(data.speed))).padStart(3, '0');
    const rpm = clamp(data.rpm, 1);
    $('rpm-value').textContent = `${Math.round(rpm * 100)}%`;
    $('rpm-track').setAttribute('aria-valuenow', Math.round(rpm * 100));
    $('rpm-fill').style.transform = `scaleX(${rpm})`;
    const health = Math.round(clamp(data.health));
    $('engine').textContent = `${health}%`;
  }

  function renderKillStreak(data) {
    state.killstreak = data;
    const root = $('killstreak');
    const count = whole(data.count);
    if (!state.sections.killstreak || data.enabled === false || data.visible === false || count < 1) {
      clearTimeout(streakAnimationTimer);
      root.classList.remove('is-hit', 'is-level-up');
      root.hidden = true;
      return;
    }

    const label = String(data.label || 'KILL STREAK').toUpperCase();
    $('streak-count').textContent = String(Math.min(999, count)).padStart(2, '0');
    $('streak-tier').textContent = label;
    root.setAttribute('aria-label', `${count} kill streak, ${label}`);
    root.hidden = false;
    root.classList.remove('is-hit', 'is-level-up');
    void root.offsetWidth;
    root.classList.add('is-hit');
    if (data.levelUp === true) root.classList.add('is-level-up');
    clearTimeout(streakAnimationTimer);
    streakAnimationTimer = setTimeout(() => {
      root.classList.remove('is-hit', 'is-level-up');
    }, data.levelUp === true ? 1400 : 650);
  }

  function resize() {
    // Keep labels readable at 720p instead of shrinking them to two-thirds size.
    const fit = Math.min(innerWidth / 900, Math.max(.85, Math.min(innerWidth / 1920, innerHeight / 1080)));
    document.documentElement.style.setProperty('--hud-scale', Math.max(.35, Math.min(1.5, fit * state.scale)));
  }

  const handlers = {
    visible: (value) => { $('hud').hidden = value !== true; },
    config: (data) => {
      state.currency = String(data.currency || '$');
      state.unit = data.unit === 'mph' ? 'mph' : 'kmh';
      state.scale = Math.max(.5, Math.min(1.5, number(data.scale, .85)));
      if (data.sections) {
        for (const name of Object.keys(state.sections)) {
          state.sections[name] = data.sections[name] !== false;
        }
      }
      const sections = state.sections;
      $('info-hud').hidden = !sections.info;
      $('status-hud').hidden = !sections.status;
      $('weapon-panel').hidden = !sections.weapon;
      $('slots').hidden = !sections.slots;
      $('combat-summary').hidden = !sections.status && !sections.weapon;
      $('combat-summary').classList.toggle('without-slots', !sections.slots);
      $('loadout').hidden = !sections.status && !sections.weapon && !sections.slots;
      renderWeapon(state.weapon);
      renderVehicle(state.vehicle);
      renderKillStreak(state.killstreak);
      $('speed-unit').textContent = state.unit === 'mph' ? 'MPH' : 'KM/H';
      resize(); renderPlayer(state.player);
    },
    safezone: (value) => {
      const inset = clamp(value, .1);
      document.documentElement.style.setProperty('--safe-x', `${inset * 100}vw`);
      document.documentElement.style.setProperty('--safe-y', `${inset * 100}vh`);
    },
    player: renderPlayer, slots: renderSlots, vitals: renderVitals,
    weapon: renderWeapon, vehicle: renderVehicle, killstreak: renderKillStreak,
  };
  window.addEventListener('message', ({ data }) => {
    if (!data || typeof data.action !== 'string' || !Object.hasOwn(handlers, data.action)) return;
    if (data.data === undefined || data.data === null) return;
    handlers[data.action](data.data);
  });
  window.addEventListener('resize', resize);
  resize(); renderSlots([]);

  if (native) {
    const handshake = async () => {
      try {
        const response = await fetch(`https://${GetParentResourceName()}/ready`, {
          method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}',
        });
        if (!response.ok) throw new Error('HUD handshake failed');
      } catch { setTimeout(handshake, 1000); }
    };
    handshake();
  }

  if (preview) {
    document.body.classList.add('preview');
    $('preview-scene').hidden = false;
    $('preview-tools').hidden = false;
    handlers.visible(true);
    handlers.config({ currency: '$', unit: 'kmh', scale: .85 });
    renderPlayer({ job: 'Los Santos Police', grade: 'Sergeant II', cash: 2450, bank: 128750, safe: { available: true, amount: 84600 } });
    renderVitals({ health: 86, armor: 65 });
    const streakLevels = [
      { kills: 2, label: 'DOUBLE KILL' }, { kills: 3, label: 'TRIPLE KILL' },
      { kills: 5, label: 'RAMPAGE' }, { kills: 8, label: 'DOMINATING' },
      { kills: 12, label: 'UNSTOPPABLE' }, { kills: 20, label: 'LEGENDARY' },
    ];
    let streak = 3;
    const streakData = (levelUp = false) => {
      let tier = 0, label = 'KILL STREAK';
      streakLevels.forEach((level, index) => { if (streak >= level.kills) { tier = index + 1; label = level.label; } });
      return { enabled: true, visible: streak > 0, count: streak, tier, label, levelUp, sequence: Date.now() };
    };
    renderKillStreak(streakData(false));
    const items = [
      { name: 'WEAPON_CARBINERIFLE', label: 'Carbine Rifle', count: 1 },
      { name: 'WEAPON_PISTOL', label: 'Combat Pistol', count: 1 },
      { name: 'bandage', label: 'Bandage', count: 6 },
      { name: 'armour_plate', label: 'Armor Plate', count: 3 },
      { name: 'WEAPON_GRENADE', label: 'Grenade', count: 2 },
    ].map((item, index) => ({ ...item, slot: index + 5, key: String(index + 1), empty: false }));
    renderSlots(items);
    let active = 0, inVehicle = true, empty = false, damaged = false, reloading = false, holstered = false;
    const equip = () => renderWeapon(empty || holstered ? { armed: false } : {
      armed: true, label: items[active].label, clip: active === 1 ? 12 : 28,
      reserve: active === 1 ? 72 : 146, slot: items[active].slot,
      showAmmo: active < 2, reloading,
    });
    const vehicle = () => renderVehicle({ active: inVehicle, speed: 127, rpm: .68, health: 94 });
    equip(); vehicle();
    $('demo-vehicle').addEventListener('click', () => { inVehicle = !inVehicle; vehicle(); });
    $('demo-holster').addEventListener('click', () => { holstered = !holstered; equip(); });
    $('demo-damage').addEventListener('click', () => { damaged = !damaged; renderVitals(damaged ? { health: 24, armor: 0 } : { health: 86, armor: 65 }); });
    $('demo-streak').addEventListener('click', () => {
      const oldTier = streakLevels.filter(level => streak >= level.kills).length;
      streak += 1;
      renderKillStreak(streakData(streakLevels.filter(level => streak >= level.kills).length > oldTier));
    });
    $('demo-streak-level').addEventListener('click', () => {
      streak = streakLevels.find(level => level.kills > streak)?.kills || streak + 5;
      renderKillStreak(streakData(true));
    });
    $('demo-empty').addEventListener('click', () => { empty = !empty; renderSlots(empty ? [] : items); equip(); });
    $('demo-hide').addEventListener('click', () => { $('hud').hidden = !$('hud').hidden; });
    document.addEventListener('keydown', (event) => {
      if (/^[1-5]$/.test(event.key)) { active = Number(event.key) - 1; equip(); }
      if (event.key.toLowerCase() === 'h') $('preview-tools').hidden = !$('preview-tools').hidden;
      if (event.key.toLowerCase() === 'r' && !reloading) {
        reloading = true; equip(); setTimeout(() => { reloading = false; equip(); }, 1200);
      }
    });
  }
})();

"use strict";

// Firefox VPN dashboard. All server data is rendered with textContent; no
// response value is ever interpreted as HTML.

const $ = (selector, root = document) => root.querySelector(selector);
const GiB = 1024 ** 3;
const LEVELS = { DEBUG: 0, INFO: 1, WARN: 2, ERROR: 3 };
const SVG_NS = "http://www.w3.org/2000/svg";

const PAGES = {
  overview: ["Overview", ""],
  locations: ["Servers", "Mozilla's exit locations"],
  accounts: ["Accounts", "Firefox Accounts used in rotation"],
  logs: ["Logs", "Live service log"],
  settings: ["Settings", "Stored in config.json in the data folder"],
  about: ["About / درباره", "FoxyVPN Pro Desktop v3 — By Mohsen Niksirat"],
  help: ["Help", "What this proxy can and cannot do"],
};

const state = {
  view: "overview",
  status: null,
  accounts: [],
  threshold: 95,
  settings: null,
  locations: [],
  pingedAt: null,
  sort: "latency",
  testing: false,
  logs: [],
  logSource: null,
  signin: null,
  pollTimer: null,
};

// ---------------------------------------------------------------- helpers

class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

async function api(method, path, body) {
  const options = { method, headers: {}, credentials: "same-origin" };
  if (method !== "GET") {
    options.headers["Content-Type"] = "application/json";
    options.body = JSON.stringify(body ?? {});
  }
  const response = await fetch(path, options);
  let data = null;
  try { data = await response.json(); } catch { /* empty body */ }
  if (response.status === 401 && path !== "/api/session") {
    showLogin();
    throw new ApiError(401, "login required");
  }
  if (!response.ok) {
    throw new ApiError(response.status, (data && data.error) || response.statusText);
  }
  return data;
}

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (value === undefined || value === null || value === false) continue;
    if (key === "class") node.className = value;
    else if (key === "text") node.textContent = value;
    else if (key.startsWith("on")) node.addEventListener(key.slice(2), value);
    else node.setAttribute(key, value === true ? "" : value);
  }
  for (const child of children.flat()) {
    if (child === null || child === undefined || child === false) continue;
    node.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
  return node;
}

function icon(name) {
  const svg = document.createElementNS(SVG_NS, "svg");
  const use = document.createElementNS(SVG_NS, "use");
  use.setAttribute("href", "#i-" + name);
  svg.append(use);
  return svg;
}

function button(label, onclick, { cls = "btn sm", iconName, title, disabled } = {}) {
  return el("button", { class: cls, title, "aria-label": title, disabled, onclick },
    iconName ? icon(iconName) : null, label ? el("span", { text: label }) : null);
}

function fact(list, label, value, mono = false) {
  if (value === undefined || value === null || value === "") return;
  list.append(el("dt", { text: label }), el("dd", { class: mono ? "mono" : "", text: value }));
}

function gib(bytes) {
  return (bytes / GiB).toFixed(bytes >= 10 * GiB ? 1 : 2);
}

function validDate(value) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) || date.getFullYear() < 2000 ? null : date;
}

function formatTime(value) {
  const date = validDate(value);
  return date ? date.toLocaleString() : "";
}

function formatDate(value) {
  const date = validDate(value);
  return date ? date.toLocaleDateString() : "";
}

function relative(value) {
  const date = validDate(value);
  if (!date) return "";
  const seconds = Math.round((date.getTime() - Date.now()) / 1000);
  const abs = Math.abs(seconds);
  const unit = abs < 90 ? [seconds, "second"] : abs < 5400 ? [Math.round(seconds / 60), "minute"] : abs < 172800 ? [Math.round(seconds / 3600), "hour"] : [Math.round(seconds / 86400), "day"];
  return new Intl.RelativeTimeFormat(undefined, { numeric: "auto" }).format(unit[0], unit[1]);
}

function duration(from) {
  const date = validDate(from);
  if (!date) return "–";
  let minutes = Math.max(0, Math.floor((Date.now() - date.getTime()) / 60000));
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  minutes %= 60;
  if (hours < 48) return `${hours}h ${String(minutes).padStart(2, "0")}m`;
  return `${Math.floor(hours / 24)}d ${hours % 24}h`;
}

let toastTimer = null;
function toast(message, bad = false) {
  const node = $("#toast");
  node.replaceChildren(icon(bad ? "bolt" : "check"), el("span", { text: message }));
  node.className = bad ? "toast bad" : "toast";
  node.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { node.hidden = true; }, bad ? 6500 : 3200);
}

function reportError(error) {
  if (error instanceof ApiError && error.status === 401) return;
  toast(error.message || String(error), true);
}

async function busy(buttonNode, label, task) {
  const original = [...buttonNode.childNodes];
  buttonNode.disabled = true;
  buttonNode.replaceChildren(el("span", { class: "spinner" }), el("span", { text: label }));
  try {
    return await task();
  } finally {
    buttonNode.replaceChildren(...original);
    buttonNode.disabled = false;
  }
}

async function copyText(text, label = text) {
  try {
    await navigator.clipboard.writeText(text);
    toast(`Copied ${label}`);
  } catch {
    toast("Copy is not available on this connection", true);
  }
}

function usagePercent(usage) {
  if (!usage || usage.unlimited || !usage.limit_bytes) return null;
  return Math.min(100, ((usage.limit_bytes - (usage.remaining_bytes || 0)) * 100) / usage.limit_bytes);
}

function levelClass(percent, threshold) {
  return percent >= threshold ? "over" : percent >= threshold - 10 ? "near" : "";
}

function quotaBar(usage, threshold) {
  const wrap = el("div", { class: "quota" });
  if (!usage) {
    wrap.append(el("div", { class: "quota-text" }, el("span", { text: "Quota unknown until first use" })));
    return wrap;
  }
  if (usage.unlimited) {
    wrap.append(el("div", { class: "quota-text" }, el("span", { text: "Unlimited quota" })));
    return wrap;
  }
  const limit = usage.limit_bytes || 0;
  const used = limit - (usage.remaining_bytes || 0);
  const percent = usagePercent(usage) ?? 0;
  const fill = el("div", { class: "quota-fill " + levelClass(percent, threshold) });
  fill.style.width = percent.toFixed(1) + "%";
  const mark = el("div", { class: "quota-mark", title: `Switches at ${threshold}%` });
  mark.style.left = Math.min(100, threshold) + "%";
  wrap.append(
    el("div", { class: "quota-bar" }, fill, mark),
    el("div", { class: "quota-text" },
      el("span", { text: `${gib(used)} / ${gib(limit)} GiB · ${percent.toFixed(0)}%` }),
      el("span", { text: usage.reset_at ? `resets ${formatDate(usage.reset_at)}` : "" })),
  );
  return wrap;
}

const STATUS_LABELS = {
  ready: "Ready",
  reserved: "Threshold reached",
  reauth_required: "Needs sign-in",
  unavailable: "Unavailable",
  disabled: "Disabled",
};
const PHASE_LABELS = { running: "Connected", waiting: "Waiting", starting: "Starting", error: "Error", off: "Off" };

// statusLabel names an account's status; a reserved account whose quota
// is spent says so instead of "Threshold reached".
function statusLabel(account, status = account.status) {
  if (status === "reserved" && account.reason_code === "quota_exhausted") return "Quota used up";
  return STATUS_LABELS[status] || status;
}

// placeName names where the proxy leaves from. Mozilla's recommended
// location names no place, so the public IP check's city and country are
// used for it when known.
function placeName(proxy, exit = state.status && state.status.exit) {
  if (!proxy) return "";
  if ((proxy.country_code || "").toUpperCase() === "REC") {
    if (!exit || !exit.country_code) return "Recommended location";
    const country = exit.country_name || countryName(exit.country_code);
    return [country, exit.city].filter(Boolean).join(" · ") + " (recommended)";
  }
  const country = proxy.country_name || proxy.country_code || "";
  const city = proxy.city_name && proxy.city_name !== country ? proxy.city_name : "";
  return [country, city].filter(Boolean).join(" · ");
}

function locationName(loc) {
  return loc.recommended ? "Recommended (anycast)" : loc.name;
}

// Secret fields. The SOCKS5 password, the new dashboard password, and the
// Firefox Account password are text fields masked with CSS (class
// "secret"), not type=password, so the browser's password manager neither
// offers saved passwords nor a generated one for them; browsers without
// -webkit-text-security fall back to type=password. Every secret, the login
// page's too, gets a button that shows and hides it.
const TEXT_SECURITY = CSS.supports("-webkit-text-security", "disc");

function setupSecrets() {
  for (const input of document.querySelectorAll("input[data-reveal]")) {
    if (input.classList.contains("secret") && !TEXT_SECURITY) input.type = "password";
    const toggle = el("button", { type: "button", class: "reveal" });
    toggle.addEventListener("click", (event) => {
      event.preventDefault();
      setRevealed(input, !input.dataset.revealed);
      input.focus();
    });
    const wrap = el("span", { class: "secret-wrap" });
    input.replaceWith(wrap);
    wrap.append(input, toggle);
    setRevealed(input, false);
  }
}

function setRevealed(input, shown) {
  input.dataset.revealed = shown ? "1" : "";
  if (input.classList.contains("secret") && TEXT_SECURITY) input.classList.toggle("revealed", shown);
  else input.type = shown ? "text" : "password";
  const toggle = input.nextElementSibling;
  toggle.title = shown ? "Hide" : "Show";
  toggle.setAttribute("aria-label", shown ? "Hide the password" : "Show the password");
  toggle.replaceChildren(icon(shown ? "eye-off" : "eye"));
}

// hideSecrets masks every secret in root again.
function hideSecrets(root) {
  for (const input of root.querySelectorAll("input[data-reveal]")) setRevealed(input, false);
}

// The public IP is the address websites see: Mozilla's exit, as reported
// by the public IP check, IPv4 and IPv6 separately (api-ipv4/api-ipv6.ip.sb,
// else Cloudflare's trace). Sites reachable over IPv6 see the IPv6 one.
const REGION_NAMES = typeof Intl.DisplayNames === "function" ? new Intl.DisplayNames(["en"], { type: "region" }) : null;

function countryName(code) {
  try {
    return (REGION_NAMES && code && REGION_NAMES.of(code.toUpperCase())) || code || "";
  } catch {
    return code || "";
  }
}

// ipPlace describes where a public IP is: "Brussels, Belgium · Network".
function ipPlace(country, city, network) {
  const where = [city, countryName(country)].filter(Boolean).join(", ");
  return [where, network].filter(Boolean).join(" · ");
}

// ipChip is the hero's public IP: flag and the IPv4 address (IPv6 without
// one); the place is in the hero's title and the chip's tooltip.
function ipChip(exit) {
  const ip = exit.ipv4 || exit.ipv6;
  const both = [exit.ipv4 && `IPv4 ${exit.ipv4}`, exit.ipv6 && `IPv6 ${exit.ipv6}`].filter(Boolean).join(", ");
  return el("span", {
    class: "chip copy ip-chip",
    title: `Public IP, the address websites see: ${both} (${ipPlace(exit.country_code, exit.city, exit.network)}). Click to copy.`,
    onclick: () => copyText(ip),
  }, flag(exit.country_code), el("span", { class: "muted", text: "Public IP" }), ip);
}

// ipBox is the connection test's public IPv4 and IPv6 address with their
// place; a click on an address copies it.
function ipBox(ipv4, ipv6, country, city, network) {
  const row = (family, ip) => el("div", { class: "ip-row", title: "Click to copy", onclick: () => copyText(ip) },
    el("span", { class: "ip-family", text: family }), el("span", { class: "ip-addr", text: ip }));
  return el("div", { class: "ip-box" },
    flag(country),
    el("div", { class: "ip-text" },
      el("div", { class: "ip-label", text: "Public IP · what websites see" }),
      ipv4 ? row("IPv4", ipv4) : null,
      ipv6 ? row("IPv6", ipv6) : null,
      el("div", { class: "muted small", text: ipPlace(country, city, network) })));
}

// flag returns the bundled flag of a two-letter country code, or a badge
// for the recommended location and unknown codes.
function flag(code, recommended = false) {
  code = (code || "").toUpperCase();
  if (recommended || code === "REC") return el("span", { class: "flag rec", title: "Recommended" }, icon("star"));
  if (!/^[A-Z]{2}$/.test(code)) return el("span", { class: "code", text: code || "?" });
  const img = el("img", { class: "flag", src: `flags/${code.toLowerCase()}.svg`, alt: code, title: code, loading: "lazy" });
  img.addEventListener("error", () => img.replaceWith(el("span", { class: "code", text: code })));
  return img;
}

// ------------------------------------------------------------- theming

function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
  $("#theme-toggle").replaceChildren(icon(theme === "dark" ? "sun" : "moon"));
}

function initTheme() {
  let theme = null;
  try { theme = localStorage.getItem("fvpn-theme"); } catch { /* storage unavailable */ }
  if (theme !== "light" && theme !== "dark") {
    theme = window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
  }
  applyTheme(theme);
}

$("#theme-toggle").addEventListener("click", () => {
  const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
  applyTheme(next);
  try { localStorage.setItem("fvpn-theme", next); } catch { /* storage unavailable */ }
});

// ------------------------------------------------------------ navigation

function showView(name) {
  if (!document.getElementById("view-" + name)) name = "overview";
  state.view = name;
  if (location.hash !== "#" + name) history.replaceState(null, "", "#" + name);
  for (const item of document.querySelectorAll(".nav-item")) item.classList.toggle("active", item.dataset.view === name);
  for (const view of document.querySelectorAll(".view")) view.hidden = view.id !== "view-" + name;
  const [title, sub] = PAGES[name];
  $("#page-title").textContent = title;
  $("#page-sub").textContent = sub;
  $("#page-sub").hidden = !sub;
  document.title = `${title} · Firefox VPN`;
  if (name === "settings") loadSettings().catch(reportError);
  if (name === "accounts") loadAccounts().catch(reportError);
  if (name === "locations") loadLocations().catch(reportError);
  if (name === "logs") renderLogs(true);
  if (name === "help") renderHelp();
}

// --------------------------------------------------------------- session

async function checkSession() {
  const info = await api("GET", "/api/session");
  $("#logout").hidden = !info.login_required;
  if (!info.authenticated) {
    showLogin(info.app_only);
    return false;
  }
  $("#login-view").hidden = true;
  $("#app").hidden = false;
  return true;
}

// The warnings above every page: a dashboard without a password, and a
// proxy open to the network without one, each with a button to the field.
function renderWarnings(s) {
  const warnings = [];
  if (!s.dashboard.login_required) {
    warnings.push([s.dashboard.exposed_without_login
      ? "This dashboard is open to other devices and has no password."
      : "This dashboard is not protected by a password.",
    "Set a password", "set-dashboard", 'input[name="dashboard.username"]']);
  }
  if (s.dashboard.socks_exposed_without_login) {
    warnings.push(["The proxy is open to other devices and has no password.",
      "Set a login", "set-local", 'input[name="proxy.username"]']);
  }
  const banner = $("#banner");
  banner.hidden = warnings.length === 0;
  // Rebuilt only when it changes: the status is read every few seconds.
  const key = warnings.map((w) => w[0]).join("|");
  if (banner.dataset.key === key) return;
  banner.dataset.key = key;
  banner.replaceChildren(...warnings.map(([text, action, section, field]) =>
    el("div", { class: "banner-row" },
      icon("alert"),
      el("span", { text }),
      el("button", { type: "button", class: "btn sm", text: action, onclick: () => openSettingsSection(section, field) }))));
}

// Opens Settings at a section and puts the cursor in a field there.
function openSettingsSection(section, field) {
  showView("settings");
  setTimeout(() => {
    const target = document.getElementById(section);
    if (target) target.scrollIntoView({ behavior: "smooth", block: "start" });
    const input = field && document.querySelector(`#settings-form ${field}`);
    if (input) input.focus({ preventScroll: true });
  }, 400);
}

// appOnly: no password exists (the phone); only the app's sign-in link
// opens the dashboard, so the form gives way to that hint.
function showLogin(appOnly = false) {
  $("#app").hidden = true;
  $("#login-view").hidden = false;
  for (const node of $("#login-form").querySelectorAll("input, button, label")) node.hidden = appOnly;
  $("#login-error").textContent = appOnly ? "Open the web dashboard from the app (About, Web dashboard): it signs you in." : "";
  stopPolling();
}

$("#login-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.target;
  $("#login-error").textContent = "";
  try {
    await api("POST", "/api/session", { username: form.username.value, password: form.password.value });
    form.password.value = "";
    await start();
  } catch (error) {
    $("#login-error").textContent = error.message;
  }
});

$("#logout").addEventListener("click", async () => {
  try { await api("DELETE", "/api/session"); } catch { /* ignore */ }
  showLogin();
});

// ---------------------------------------------------------------- status

async function loadStatus() {
  state.status = await api("GET", "/api/status");
  state.threshold = state.status.switch_threshold_percent || 95;
  renderStatus();
}

function renderStatus() {
  const s = state.status;
  if (!s) return;
  const phase = s.state.phase;
  const label = PHASE_LABELS[phase] || phase;

  $("#version-tag").textContent = s.version ? `Firefox VPN ${s.version}` : "";
  const pill = $("#state-pill");
  const asleep = phase === "running" && s.proxy && s.proxy.sleeping_since;
  // A sleeping proxy has its own look everywhere: it is not connected.
  const look = asleep ? "sleeping" : phase;
  pill.className = "pill " + look;
  pill.textContent = asleep ? "Sleeping" : label;
  $("#mini-status").className = "mini-status " + look;
  // The recommended location shows the flag of the country it leaves from.
  const placeCode = s.proxy && (s.proxy.country_code || "").toUpperCase() === "REC" && s.exit && s.exit.country_code ? s.exit.country_code : s.proxy && s.proxy.country_code;
  $("#mini-flag")?.replaceChildren(...(s.proxy ? [flag(placeCode)] : []), el("span", { class: "dot" }));
  if ($("#hero-flag")) $("#hero-flag").replaceChildren(...(phase === "running" && s.proxy ? [flag(placeCode)] : []));
  $("#mini-title").textContent = asleep ? "Sleeping" : label;
  $("#mini-sub").textContent = s.proxy ? (asleep ? "wakes on use · " : "") + placeName(s.proxy) : s.state.message;

  renderWarnings(s);

  const needSignIn = (s.accounts.reauth_required || 0) + (s.accounts.unavailable || 0);
  $("#nav-accounts-badge").hidden = needSignIn === 0;
  $("#nav-accounts-badge").textContent = String(needSignIn);

  // Master VPN Card elements
  const masterBtn = $("#master-connect-btn");
  const masterIcon = $("#master-btn-icon");
  const masterLabel = $("#master-btn-label");
  const masterTitle = $("#master-status-title");
  const masterSub = $("#master-status-sub");
  const masterPulse = $("#master-status-pulse");
  const tunPill = $("#tun-status-pill");
  const transportBadge = $("#transport-badge");
  const heroQuickFlag = $("#hero-quick-flag");
  const heroQuickLoc = $("#hero-quick-location");

  if (masterBtn) {
    if (phase === "running") {
      masterBtn.className = "power-circle-btn state-connected";
      if (masterLabel) masterLabel.textContent = "DISCONNECT";
      if (masterTitle) masterTitle.textContent = "Connected / متصل";
      if (masterPulse) {
        masterPulse.style.background = "#10b981";
        masterPulse.style.boxShadow = "0 0 12px #10b981";
      }
      if (masterSub) {
        masterSub.textContent = asleep
          ? "در حالت آماده‌باش (Sleep): به محض اولین ترافیک بیدار می‌شود · ترافیک محافظت شده"
          : (s.proxy ? `متصل به سرور Fastly موزیلا (${placeName(s.proxy)}) · اینترنت سیستم آزاد و امن است` : "متصل به سرویس");
      }
    } else if (phase === "connecting" || state.connecting) {
      masterBtn.className = "power-circle-btn state-connecting";
      if (masterLabel) masterLabel.textContent = "CONNECTING...";
      if (masterTitle) masterTitle.textContent = "Connecting... / در حال اتصال";
      if (masterPulse) {
        masterPulse.style.background = "#f59e0b";
        masterPulse.style.boxShadow = "0 0 12px #f59e0b";
      }
      if (masterSub) masterSub.textContent = "در حال ایجاد تونل امن، دریافت کلیدها و پیکربندی شبکه...";
    } else {
      masterBtn.className = "power-circle-btn state-off";
      if (masterLabel) masterLabel.textContent = "CONNECT";
      if (masterTitle) masterTitle.textContent = "Disconnected / قطع";
      if (masterPulse) {
        masterPulse.style.background = "#8a92a6";
        masterPulse.style.boxShadow = "none";
      }
      if (masterSub) masterSub.textContent = "برای اتصال فیلترشکن و شروع تونل کل سیستم، دکمه CONNECT را بزنید.";
    }
  }

  if (tunPill) {
    if (s.tun_active) {
      tunPill.textContent = "TUN: Active (کل سیستم)";
      tunPill.style.background = "rgba(16, 185, 129, 0.2)";
      tunPill.style.color = "#10b981";
    } else {
      tunPill.textContent = s.tun_admin ? "TUN: Inactive (آماده)" : "TUN: Inactive";
      tunPill.style.background = "rgba(255, 255, 255, 0.08)";
      tunPill.style.color = "var(--muted)";
    }
  }

  if (transportBadge && s.proxy) {
    transportBadge.textContent = s.proxy.transport === "h3" ? "HTTP/3 · QUIC" : "HTTP/2 · TLS";
  }

  if (heroQuickFlag && heroQuickLoc) {
    if (s.proxy && phase === "running") {
      heroQuickFlag?.replaceChildren(flag(placeCode));
      heroQuickLoc.textContent = placeName(s.proxy) || "Auto";
    } else {
      const mode = currentMode();
      if (mode.kind === "recommended") {
        heroQuickFlag?.replaceChildren();
        heroQuickLoc.textContent = "Auto (Recommended)";
      } else if (mode.kind === "fastest") {
        heroQuickFlag?.replaceChildren();
        heroQuickLoc.textContent = "⚡ Auto (Fastest)";
      } else {
        heroQuickFlag?.replaceChildren(flag(mode.value));
        heroQuickLoc.textContent = mode.value.toUpperCase();
      }
    }
  }

  // Fallback elements
  const sleeping = asleep;
  let message = phase === "running" ? (s.proxy ? s.proxy.upstream : "") : s.state.message;
  if (s.state.retry_at && phase !== "running") message += ` · next attempt ${relative(s.state.retry_at)}`;
  if (s.pass && s.pass.last_error) message += ` · last renewal error: ${s.pass.last_error}`;
  if (phase === "off") message = "Turned off: the proxy port is closed and nothing connects to Mozilla. Turn it on here or in the app.";
  if (sleeping) message = `No connection through Mozilla since ${relative(s.proxy.sleeping_since)}: the session is closed and the account is not used. The next connection, a connection test, or a real-delay test wakes it in a few seconds.`;

  if ($("#hero-pulse")) $("#hero-pulse").className = "pulse " + look;
  if ($("#hero-eyebrow")) $("#hero-eyebrow").textContent = sleeping ? "Sleeping: wakes on the next connection" : phase === "running" ? "Connected through Mozilla VPN" : "Proxy status";
  if ($("#hero-title")) $("#hero-title").textContent = phase === "running" ? placeName(s.proxy) || "Connected" : label;
  if ($("#hero-message")) $("#hero-message").textContent = message;
  const chips = $("#hero-chips");
  if (chips) chips.replaceChildren();
  if (s.proxy) {
    // Node.append writes null as the text "null"; leave absent chips out.
    chips.append(...[
      el("span", { class: "chip copy", title: "Copy the proxy address (SOCKS5 and HTTP)", onclick: () => copyText(s.proxy.listen) }, icon("copy"), "Proxy " + s.proxy.listen),
      s.proxy.login_required ? el("span", { class: "chip ok", title: "Clients need the SOCKS5 username and password" }, icon("lock"), "Login required") : null,
      el("span", { class: "chip accent", text: s.proxy.transport === "h3" ? "HTTP/3 · QUIC" : "HTTP/2 · TLS" }),
      s.exit ? ipChip(s.exit) : null,
    ].filter(Boolean));
  }
  if ($("#run-test")) $("#run-test").disabled = phase !== "running" || state.testing;
  if ($("#power span")) $("#power span").textContent = phase === "off" ? "Turn on" : "Turn off";

  // TUN mode status update
  const tunCard = document.getElementById("tun-card");
  if (tunCard) {
    tunCard.hidden = !s.tun_supported;
    const badge = document.getElementById("tun-status-badge");
    const btn = document.getElementById("tun-toggle-btn");
    if (s.tun_active) {
      if (badge) {
        badge.textContent = "Active (Connected)";
        badge.style.background = "var(--ok, #34d399)";
        badge.style.color = "#000";
      }
      if (btn) {
        btn.querySelector("span").textContent = "Disable TUN Mode";
        btn.style.background = "linear-gradient(135deg, #ff5c6c, #e04858)";
      }
    } else {
      if (badge) {
        badge.textContent = s.tun_admin ? "Ready (Admin)" : "Admin Required";
        badge.style.background = s.tun_admin ? "rgba(0, 210, 255, 0.2)" : "rgba(255, 92, 108, 0.2)";
        badge.style.color = s.tun_admin ? "#00d2ff" : "#ff5c6c";
      }
      if (btn) {
        btn.querySelector("span").textContent = "Enable TUN Mode";
        btn.style.background = "linear-gradient(135deg, #00d2ff, #7c5bff)";
      }
    }
  }
  if ($("#power")) $("#power").classList.toggle("primary", phase === "off");
  $("#restart-proxy").disabled = phase === "off";

  // KPIs.
  const active = s.active_account;
  const percent = active ? usagePercent(active.usage) : null;
  const gauge = $("#gauge-fill");
  const circumference = 2 * Math.PI * 17;
  gauge.setAttribute("stroke-dasharray", `${((percent ?? 0) / 100) * circumference} ${circumference}`);
  gauge.setAttribute("class", "gauge-fill " + (percent === null ? "" : levelClass(percent, state.threshold)));
  $("#kpi-usage").textContent = percent === null ? (active && active.usage && active.usage.unlimited ? "∞" : "–") : `${percent.toFixed(0)}%`;
  $("#kpi-usage-sub").textContent = active ? active.name : s.accounts.total ? "No active account" : "Add an account to start";
  $("#kpi-account").title = s.accounts.total ? `${s.accounts.ready || 0} of ${s.accounts.total} accounts ready · the next one takes over at ${state.threshold}%` : "";
  const test = s.last_test;
  $("#kpi-latency").textContent = test && test.ok ? `${test.total_ms} ms` : "–";
  $("#kpi-latency-sub").textContent = test ? (test.ok ? `tested ${relative(test.at)}` : "last test failed") : "Run a connection test";
  renderSpeed(s.traffic);
  $("#kpi-uptime-label").textContent = asleep ? "Asleep for" : "Uptime";
  $("#kpi-uptime").textContent = s.proxy ? duration(asleep ? s.proxy.sleeping_since : s.proxy.started_at) : "–";
  $("#kpi-uptime-sub").textContent = asleep ? `no session · up ${duration(s.proxy.started_at)} in all`
    : s.pass && s.pass.proxy_pass_expires_at ? `pass renews ${relative(s.pass.proxy_pass_expires_at)}` : "";

  // Active account card.
  const box = $("#active-account");
  if (box) box.replaceChildren();
  if (active) {
    box.append(
      el("div", { class: "account-hero" },
        el("div", { class: "avatar", text: (active.name || "?").charAt(0).toUpperCase() }),
        el("div", {},
          el("div", { class: "account-name", text: active.name }),
          el("div", { class: "account-meta" },
            el("span", { class: "chip " + active.status, text: statusLabel(active) }),
            active.email && active.email !== active.name ? el("span", { text: active.email }) : null))),
      quotaBar(active.usage, state.threshold),
    );
  } else {
    box.append(el("p", { class: "muted", text: s.accounts.total ? "No account is active right now." : "No accounts yet. Add one on the Accounts page." }));
  }

  // Proxy facts.
  const facts = $("#proxy-facts");
  if (facts) facts.replaceChildren();
  if (s.proxy) {
    fact(facts, "SOCKS5", s.proxy.listen + (s.proxy.login_required ? " (username and password required)" : ""), true);
    fact(facts, "Location", placeName(s.proxy) || "Unknown");
    fact(facts, "Server", s.proxy.upstream, true);
    fact(facts, "Selected by", (s.proxy.selection_source || "").replaceAll("_", " "));
    fact(facts, "Running since", formatTime(s.proxy.started_at));
  } else {
    fact(facts, "State", s.state.message);
  }
  if (s.pass) fact(facts, "Proxy pass", `${s.pass.accepting ? "valid" : "not accepting"}, renews before ${formatTime(s.pass.proxy_pass_expires_at)}`);
  fact(facts, "Data folder", s.data_dir, true);

  renderNotices(s.notices);
  renderTest(test);
  renderRecentLog();
}

// Notices explain requests refused in the last five minutes because of a
// limit (a port Mozilla's proxy refuses, UDP); the server sends only those.
// Each one shows the latest destinations and can be closed on its own;
// closing hides it until the next refusal of the same kind.
const NOTICE_TEXT = {
  port: (n) => [`Mozilla's proxy refused port ${n.detail}`, "It connects to ports 80, 443, 8080, and 8443 only; sites on other ports do not open through it.", "help-ports"],
  command: (n) => [`An application asked for ${n.detail}`, "Mozilla's proxy carries TCP connections only; games, calls, and other UDP traffic do not go through it.", "help-udp"],
};

function noticeKey(n) {
  return `${n.kind}:${n.detail}`;
}

function noticesClosed() {
  try {
    return JSON.parse(localStorage.getItem("fvpn-notices-closed") || "{}") || {};
  } catch {
    return {};
  }
}

function closeNotice(n) {
  const closed = noticesClosed();
  closed[noticeKey(n)] = n.last;
  try { localStorage.setItem("fvpn-notices-closed", JSON.stringify(closed)); } catch { /* storage unavailable */ }
  renderNotices(state.status && state.status.notices);
}

function renderNotices(notices) {
  const box = $("#notices");
  if (!box) return;
  const closed = noticesClosed();
  const shown = (notices || []).filter((n) => NOTICE_TEXT[n.kind] && Date.parse(n.last) > (Date.parse(closed[noticeKey(n)]) || 0));
  box.hidden = shown.length === 0;
  box.replaceChildren(...shown.slice(0, 3).map((n) => {
    const [title, text, anchor] = NOTICE_TEXT[n.kind](n);
    const times = n.count > 1 ? `${n.count} times, last ${relative(n.last)}` : relative(n.last);
    const hosts = n.hosts && n.hosts.length ? el("div", { class: "notice-hosts" },
      el("span", { class: "muted", text: n.hosts.length > 1 ? "Destinations: " : "Destination: " }),
      ...n.hosts.map((h) => el("code", { text: n.kind === "port" ? hostPort(h, n.detail) : h }))) : null;
    return el("div", { class: "notice" },
      icon("alert"),
      el("div", { class: "notice-body" },
        el("div", {}, el("strong", { text: title }), el("span", { class: "muted", text: ` · ${times}` })),
        hosts,
        el("div", { class: "muted" }, text + " ",
          el("a", { href: "#help", onclick: (event) => { event.preventDefault(); openHelp(anchor); }, text: "Help" }))),
      el("button", { type: "button", class: "btn ghost icon sm notice-close", title: "Hide", "aria-label": "Hide this note", onclick: () => closeNotice(n) },
        el("span", { text: "×" })));
  }));
}

// hostPort joins a destination and port, with brackets for IPv6.
function hostPort(host, port) {
  return host.includes(":") ? `[${host}]:${port}` : `${host}:${port}`;
}

// Routing settings: the rule lists are textareas (one rule per line) and
// the update interval is edited in days.
function fillRoutingFields(routing) {
  $("#routing-direct").value = (routing.direct || []).join("\n");
  $("#routing-block").value = (routing.block || []).join("\n");
  const hours = parseInt((String(routing.update_interval || "").match(/(\d+)h/) || [])[1] || "240", 10);
  $("#routing-days").value = Math.max(1, Math.round(hours / 24));
  syncAdsSwitch();
}

// "Block ads" is a shortcut for one Block rule, which the list shows too.
const ADS_RULE = "geosite:category-ads-all";

function blockLines() {
  return $("#routing-block").value.split("\n").map((line) => line.trim()).filter(Boolean);
}

function syncAdsSwitch() {
  $("#routing-ads").checked = blockLines().some((rule) => rule.toLowerCase() === ADS_RULE);
}

$("#routing-ads").addEventListener("change", (event) => {
  const others = blockLines().filter((rule) => rule.toLowerCase() !== ADS_RULE);
  $("#routing-block").value = (event.target.checked ? [...others, ADS_RULE] : others).join("\n");
});
$("#routing-block").addEventListener("input", syncAdsSwitch);

function routingFromForm(config) {
  const lines = (selector) => $(selector).value.split("\n").map((line) => line.trim()).filter(Boolean);
  config.routing = config.routing || {};
  config.routing.direct = lines("#routing-direct");
  config.routing.block = lines("#routing-block");
  const days = Math.min(365, Math.max(1, parseInt($("#routing-days").value, 10) || 10));
  config.routing.update_interval = `${days * 24}h`;
}

async function loadRoutingStatus() {
  renderRoutingStatus(await api("GET", "/api/routing"));
}

function renderRoutingStatus(view) {
  state.regionRules = view.region_rules || [];
  renderSourceSelect(view.sources || []);
  const [label, cls, note] = !view.enabled ? ["Off", "", "Everything goes through Mozilla"]
    : view.active ? ["On", "ok", ""]
    : ["Not working", "bad", `Everything goes through Mozilla: ${view.error || "the files are loading"}`];
  // Node.replaceChildren writes null as the text "null"; leave it out.
  $("#routing-state").replaceChildren(...[
    el("span", { class: `chip ${cls}`, text: view.updating ? "Downloading…" : label }),
    note ? el("span", { class: "muted small", text: note }) : null,
  ].filter(Boolean));
  const files = view.files || [];
  // The oldest file says when the files were last brought up to date.
  const oldest = files.map((f) => validDate(f.updated_at)).filter(Boolean).sort((a, b) => a - b)[0];
  $("#routing-files").replaceChildren(...[
    files.length
      ? el("span", { text: `Updated ${relative(oldest)}` })
      : el("span", { text: "Not downloaded yet" }),
    files.length ? el("span", { class: "muted", text: files.map((f) => `${f.name} ${(f.size / 1048576).toFixed(1)} MB`).join(" · ") }) : null,
    view.last_error ? el("span", { class: "form-error", text: `The last update failed: ${view.last_error}` }) : null,
  ].filter(Boolean));
}

// The list source fills the two URL fields; URLs typed by hand make it
// "Set by hand".
function renderSourceSelect(sources) {
  state.listSources = sources;
  const select = $("#routing-source");
  if (select.options.length !== sources.length + 1) {
    select.replaceChildren(el("option", { value: "", text: "Set by hand (the URLs below)" }), ...sources.map((s) => el("option", { value: s.id, text: s.name })));
  }
  syncSourceSelect();
}

function syncSourceSelect() {
  const site = $('#settings-form input[name="routing.geosite_url"]').value.trim();
  const ip = $('#settings-form input[name="routing.geoip_url"]').value.trim();
  const match = (state.listSources || []).find((s) => s.geosite_url === site && s.geoip_url === ip);
  $("#routing-source").value = match ? match.id : "";
}

$("#routing-source").addEventListener("change", (event) => {
  const src = (state.listSources || []).find((s) => s.id === event.target.value);
  if (!src) return;
  $('#settings-form input[name="routing.geosite_url"]').value = src.geosite_url;
  $('#settings-form input[name="routing.geoip_url"]').value = src.geoip_url;
  updateDirty();
});
for (const name of ["routing.geosite_url", "routing.geoip_url"]) {
  $(`#settings-form input[name="${name}"]`).addEventListener("input", syncSourceSelect);
}

// Restore puts the saved region's rules back at the top of the Direct
// list, keeping the user's own; Save settings applies it.
$("#routing-restore").addEventListener("click", () => {
  const box = $("#routing-direct");
  const presets = state.regionRules || [];
  const seen = new Set(presets.map((rule) => rule.toLowerCase()));
  const own = box.value.split("\n").map((line) => line.trim()).filter((line) => line && !seen.has(line.toLowerCase()));
  box.value = [...presets, ...own].join("\n");
  updateDirty();
  toast("The country's rules are back in the list; save to apply them");
});

// The destination test asks the service where a destination goes.
const ROUTE_LABELS = { direct: ["Direct", "ok"], proxy: ["Through Mozilla", "accent"], block: ["Blocked", "bad"] };

async function testDestination() {
  const box = $("#route-test-result");
  const target = $("#route-target").value.trim();
  if (!target) return;
  await busy($("#route-test"), "Testing…", async () => {
    try {
      const r = await api("POST", "/api/routing/test", { target });
      const [label, cls] = ROUTE_LABELS[r.route] || [r.route, ""];
      const where = r.port ? hostPort(r.host, r.port) : r.host;
      const why = r.rule ? `by the rule ${r.rule}` : r.note || "no rule matches";
      // Node.replaceChildren writes null as the text "null"; leave it out.
      box.replaceChildren(...[
        el("span", { class: `chip ${cls}`, text: label }),
        el("code", { text: where }),
        el("span", { class: "muted", text: why + (r.resolved ? ` (looked up through Mozilla: ${r.resolved})` : "") }),
        r.port_refused ? el("span", { class: "warn-line", text: `Mozilla's proxy does not connect to port ${r.port}; it connects to 80, 443, 8080, and 8443 only. A Direct rule for this destination would let it open.` }) : null,
      ].filter(Boolean));
    } catch (error) {
      box.replaceChildren(el("span", { class: "form-error", text: error.message }));
    }
  });
}

$("#route-test").addEventListener("click", testDestination);
$("#route-target").addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault(); // not the settings form's submit
    testDestination();
  }
});

$("#routing-update").addEventListener("click", (event) => busy(event.currentTarget, "Downloading…", async () => {
  try {
    renderRoutingStatus(await api("POST", "/api/routing/update"));
    toast("Routing lists updated");
  } catch (error) {
    reportError(error);
    loadRoutingStatus().catch(() => {});
  }
}));

// The Help page's connection card shows the SOCKS5 address and a share
// link (socks://base64(user:password)@host:port#name, as v2rayN and v2rayNG
// export it) built from the settings. A proxy listening on all addresses is
// shown with the address this dashboard was opened at.
async function renderHelp() {
  let proxy = state.settings && state.settings.config.proxy;
  if (!proxy) {
    try {
      proxy = (await api("GET", "/api/settings")).config.proxy;
    } catch {
      return;
    }
  }
  const listen = proxy.listen || "127.0.0.1:10810";
  const cut = listen.lastIndexOf(":");
  let host = listen.slice(0, cut).replace(/^\[|\]$/g, "");
  const port = listen.slice(cut + 1);
  if (host === "" || host === "0.0.0.0" || host === "::") {
    host = ["localhost", "127.0.0.1", "[::1]", ""].includes(location.hostname) ? "127.0.0.1" : location.hostname.replace(/^\[|\]$/g, "");
  }
  const hostPart = host.includes(":") ? `[${host}]` : host;
  const address = `${hostPart}:${port}`;
  const userinfo = base64(`${proxy.username || ""}:${proxy.password || ""}`).replace(/=+$/, "");
  const link = `socks://${userinfo}@${address}#${encodeURIComponent("🦊Firefox VPN")}`;
  $("#help-socks-addr").textContent = address;
  // The password stays out of sight; the copied link has it.
  $("#help-socks-link").textContent = proxy.password ? `socks://…@${address}#🦊Firefox VPN` : `socks://${userinfo}@${address}#🦊Firefox VPN`;
  $("#help-copy-addr").onclick = () => copyText(address);
  $("#help-copy-link").onclick = () => copyText(link, "the link");
}

function base64(text) {
  let binary = "";
  for (const byte of new TextEncoder().encode(text)) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function openHelp(anchor) {
  showView("help");
  const target = document.getElementById(anchor);
  if (target) {
    target.scrollIntoView({ block: "start", behavior: "smooth" });
    target.classList.add("flash");
    setTimeout(() => target.classList.remove("flash"), 1600);
  }
}

// renderSpeed shows the current speed (averaged by the server over the
// last seconds) and what was transferred since the proxy started.
function renderSpeed(traffic) {
  if (!traffic) {
    $("#kpi-down").textContent = "–";
    $("#kpi-speed-sub").textContent = "";
    return;
  }
  $("#kpi-down").textContent = formatRate(traffic.down_rate);
  const total = `${formatBytes(traffic.down + traffic.direct_down)} ↓ ${formatBytes(traffic.up + traffic.direct_up)} ↑`;
  const direct = traffic.direct_down + traffic.direct_up;
  const sub = $("#kpi-speed-sub");
  sub.replaceChildren(el("span", { class: "speed-up", text: `↑ ${formatRate(traffic.up_rate)}` }), ` · ${total}`);
  sub.title = `Since the proxy started: ${formatBytes(traffic.down)} down and ${formatBytes(traffic.up)} up through Mozilla` +
    (direct ? `, ${formatBytes(traffic.direct_down)} down and ${formatBytes(traffic.direct_up)} up directly (routing)` : "");
}

function formatBytes(bytes) {
  const units = ["B", "KB", "MB", "GB", "TB"];
  let value = bytes || 0;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return `${value >= 100 || unit === 0 ? Math.round(value) : value.toFixed(1)} ${units[unit]}`;
}

function formatRate(bytesPerSecond) {
  return `${formatBytes(bytesPerSecond)}/s`;
}

function renderTest(result) {
  const box = $("#test-result");
  $("#test-when").textContent = result ? relative(result.at) : "";
  if (!result) return;
  if (box) box.replaceChildren();
  if (!result.ok) {
    box.append(el("div", { class: "test-head" }, el("span", { class: "chip bad", text: "Failed" })), el("p", { class: "muted", text: result.error }));
    return;
  }
  const total = Math.max(1, result.total_ms);
  const segment = (cls, ms) => {
    const div = el("div", { class: cls, title: `${ms} ms` });
    div.style.width = ((ms / total) * 100).toFixed(1) + "%";
    return div;
  };
  const tunnel = result.tunnel_ms || 0;
  const tls = result.tls_ms || 0;
  const response = result.response_ms ?? Math.max(0, (result.first_byte_ms || 0) - tunnel - tls);
  const stage = (cls, name, ms, title) => el("span", { title }, el("i", { class: cls }), `${name} ${ms} ms`);
  box.replaceChildren(...[
    el("div", { class: "test-head" },
      el("span", { class: "test-total", text: `${result.total_ms} ms` }),
      el("span", { class: "chip ok", text: `HTTP ${result.http_status}` })),
    el("div", { class: "timeline" }, segment("t-tunnel", tunnel), segment("t-tls", tls), segment("t-first", response)),
    el("div", { class: "legend" },
      stage("t-tunnel", "Tunnel", tunnel, "Opening the tunnel through Mozilla's proxy server"),
      stage("t-tls", "TLS", tls, "The encrypted handshake with the test site"),
      stage("t-first", "Response", response, "From sending the request to the first byte of the answer")),
    result.exit_ipv4 || result.exit_ipv6 ? ipBox(result.exit_ipv4, result.exit_ipv6, result.exit_country, result.exit_city, result.exit_network) : null,
    result.exit_error ? el("p", { class: "muted small", text: `Public IP check: ${result.exit_error}` }) : null,
  ].filter(Boolean));
}

$("#run-test").addEventListener("click", async (event) => {
  const node = event.currentTarget;
  state.testing = true;
  try {
    const result = await busy(node, "Testing…", () => api("POST", "/api/test"));
    renderTest(result);
    toast(result.ok ? `Connection OK in ${result.total_ms} ms` : "Connection test failed", !result.ok);
    loadStatus().catch(reportError);
  } catch (error) {
    reportError(error);
  } finally {
    state.testing = false;
  }
});

// Off closes the proxy's port and stops using Mozilla (the app's power
// button does the same); on starts it again.
$("#power").addEventListener("click", async () => {
  const on = Boolean(state.status && state.status.state.phase === "off");
  try {
    await api("POST", "/api/power", { on });
    toast(on ? "Turning the proxy on" : "Proxy turned off");
    setTimeout(() => loadStatus().catch(reportError), 800);
  } catch (error) { reportError(error); }
});

$("#restart-proxy").addEventListener("click", async () => {
  try {
    await api("POST", "/api/proxy/restart");
    toast("Restarting the proxy");
    setTimeout(() => loadStatus().catch(reportError), 800);
  } catch (error) { reportError(error); }
});

// -------------------------------------------------------------- accounts

async function loadAccounts() {
  const data = await api("GET", "/api/accounts");
  state.accounts = data.accounts || [];
  state.threshold = data.switch_threshold_percent || state.threshold;
  renderAccounts();
}

function renderAccounts() {
  const list = $("#account-list");
  list.replaceChildren();
  $("#accounts-hint").textContent = `Accounts are used top to bottom. The next one takes over when the active account has used ${state.threshold}% of its quota.`;
  if (state.accounts.length === 0) {
    list.append(el("div", { class: "card empty" }, icon("accounts"), el("strong", { text: "No accounts yet" }), el("span", { text: "Use “Add account” to sign in with a Firefox Account." })));
    return;
  }
  state.accounts.forEach((account, index) => {
    const status = account.enabled ? account.status : "disabled";
    // The active account is ready by definition: "Active" takes the place
    // of "Ready", so every row keeps its chips on one line.
    const meta = el("div", { class: "account-meta" },
      account.active && status === "ready" ? el("span", { class: "chip active", text: "Active" }) : el("span", { class: "chip " + status, text: statusLabel(account, status) }),
      account.email && account.email !== account.name ? el("span", { text: account.email }) : null,
      account.retry_at && account.status !== "ready" ? el("span", { text: `until ${formatTime(account.retry_at)}` }) : null,
      account.has_password ? el("span", { class: "chip", title: "The password is saved (encrypted). When this account's tokens stop working and cannot be renewed, the program signs in again by itself.", text: "Auto re-login" }) : null,
    );
    const reason = account.reason ? el("div", { class: "account-meta", text: account.reason }) : null;
    const actions = el("div", { class: "account-actions" },
      button("", () => moveAccount(index, -1), { cls: "btn ghost icon sm", iconName: "up", title: "Move up", disabled: index === 0 }),
      button("", () => moveAccount(index, 1), { cls: "btn ghost icon sm", iconName: "down", title: "Move down", disabled: index === state.accounts.length - 1 }),
      // An account that must sign in again cannot be used before that.
      account.enabled && !account.active && account.status !== "reauth_required" ? button("Use now", () => accountAction(account, "activate", "Switching to this account")) : null,
      button("", () => accountAction(account, "refresh", "Quota refreshed"), { cls: "btn ghost icon sm", iconName: "refresh", title: "Refresh quota" }),
      account.status === "reauth_required" ? button("Sign in again", () => signInAgain(account), { cls: "btn sm primary" }) : null,
      button(account.enabled ? "Disable" : "Enable", () => setEnabled(account, !account.enabled)),
      button("", () => removeAccount(account), { cls: "btn ghost icon sm danger", iconName: "trash", title: "Remove" }),
    );
    const handle = el("div", { class: "position drag-handle", title: "Drag to change the order", text: String(account.position) });
    const card = el("article", { class: "card account" + (account.enabled ? "" : " inactive") + (account.active ? " is-active" : ""), "data-id": account.id },
      handle,
      el("div", { class: "account-hero" },
        el("div", { class: "avatar", text: (account.name || "?").charAt(0).toUpperCase() }),
        el("div", {}, el("div", { class: "account-name", text: account.name }), meta, reason)),
      quotaBar(account.usage, state.threshold),
      actions,
    );
    enableAccountDrag(card, handle);
    list.append(card);
  });
}

async function moveAccount(index, delta) {
  const ids = state.accounts.map((a) => a.id);
  const [moved] = ids.splice(index, 1);
  ids.splice(index + delta, 0, moved);
  await saveAccountOrder(ids);
}

async function saveAccountOrder(ids) {
  try {
    await api("POST", "/api/accounts/order", { ids });
    await loadAccounts();
  } catch (error) { reportError(error); }
}

// Drag and drop: a card is dragged by its position number (only the
// handle starts a drag, so text and buttons keep working) and dropped
// before or after another card. Phones keep the arrow buttons: browsers
// do not drag with touch.
let draggedAccount = null;

function enableAccountDrag(card, handle) {
  handle.addEventListener("pointerdown", () => { card.draggable = true; });
  card.addEventListener("dragstart", (event) => {
    draggedAccount = card.dataset.id;
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", draggedAccount);
    card.classList.add("dragging");
  });
  card.addEventListener("dragend", () => {
    card.draggable = false;
    card.classList.remove("dragging");
    draggedAccount = null;
    for (const c of document.querySelectorAll(".account")) c.classList.remove("drop-before", "drop-after");
  });
  card.addEventListener("dragover", (event) => {
    if (!draggedAccount || draggedAccount === card.dataset.id) return;
    event.preventDefault();
    const box = card.getBoundingClientRect();
    const after = event.clientY > box.top + box.height / 2;
    card.classList.toggle("drop-after", after);
    card.classList.toggle("drop-before", !after);
  });
  card.addEventListener("dragleave", () => card.classList.remove("drop-before", "drop-after"));
  card.addEventListener("drop", (event) => {
    event.preventDefault();
    const moved = draggedAccount;
    const after = card.classList.contains("drop-after");
    card.classList.remove("drop-before", "drop-after");
    if (!moved || moved === card.dataset.id) return;
    const ids = state.accounts.map((a) => a.id).filter((id) => id !== moved);
    const at = ids.indexOf(card.dataset.id) + (after ? 1 : 0);
    ids.splice(at, 0, moved);
    saveAccountOrder(ids);
  });
}

async function accountAction(account, action, message) {
  try {
    await api("POST", `/api/accounts/${encodeURIComponent(account.id)}/${action}`);
    toast(message);
    setTimeout(() => { loadAccounts().catch(reportError); loadStatus().catch(reportError); }, 600);
  } catch (error) { reportError(error); }
}

async function setEnabled(account, enabled) {
  try {
    await api("POST", `/api/accounts/${encodeURIComponent(account.id)}/enabled`, { enabled });
    await loadAccounts();
  } catch (error) { reportError(error); }
}

async function removeAccount(account) {
  if (!confirm(`Remove ${account.name}? Its stored credentials are deleted.`)) return;
  try {
    await api("DELETE", `/api/accounts/${encodeURIComponent(account.id)}`);
    toast("Account removed");
    await loadAccounts();
  } catch (error) { reportError(error); }
}

// ------------------------------------------------------------- locations

async function loadLocations() {
  const [data, settings] = await Promise.all([
    api("GET", "/api/locations"),
    state.settings ? Promise.resolve(state.settings) : api("GET", "/api/settings"),
  ]);
  state.settings = settings;
  state.locations = data.locations || [];
  state.pingedAt = validDate(data.pinged_at);
  state.firefoxVersion = data.firefox_version || "";
  renderLocations();
  populateHeroQuickSelect();
}

function populateHeroQuickSelect() {
  const sel = $("#hero-quick-select");
  if (!sel) return;
  const current = currentMode();
  sel.innerHTML = "";
  sel.append(el("option", { value: "" }, "Auto (Recommended)"));
  sel.append(el("option", { value: "fastest" }, "⚡ Auto (Fastest)"));
  for (const loc of state.locations) {
    const label = `${locationName(loc)} (${loc.code})${loc.ping_ms ? ` · ${loc.ping_ms}ms` : ""}`;
    sel.append(el("option", { value: loc.code }, label));
  }
  if (current.kind === "recommended") sel.value = "";
  else if (current.kind === "fastest") sel.value = "fastest";
  else if (current.kind === "country") sel.value = current.value;
}

function currentMode() {
  const proxy = state.settings ? state.settings.config.proxy : {};
  if (proxy.server) return { kind: "server", value: proxy.server };
  const country = (proxy.country || "").trim();
  if (!country) return { kind: "recommended" };
  if (country.toLowerCase() === "fastest") return { kind: "fastest" };
  return { kind: "country", value: country };
}

function renderLocations() {
  if (!state.settings) {
    $("#mode-title").textContent = "Loading…";
    return;
  }
  const mode = currentMode();
  const running = state.status && state.status.proxy;
  const currentCode = running ? (state.status.proxy.country_code || "").toUpperCase() : "";
  const titles = {
    recommended: ["Auto (recommended)", "Mozilla picks the server, as Firefox does by default."],
    fastest: ["Auto (fastest)", "The server with the lowest real delay is tested and chosen whenever the proxy starts."],
    server: [`Custom server ${mode.value}`, "Set in Settings."],
  };
  const match = state.locations.find((l) => mode.value && (l.code.toLowerCase() === mode.value.toLowerCase() || l.name.toLowerCase() === mode.value.toLowerCase()));
  const [title, sub] = titles[mode.kind] || [`Manual: ${match ? match.name : mode.value}`, "The proxy always uses this server."];
  $("#mode-title").textContent = title;
  $("#mode-sub").textContent = sub + (running ? ` Now: ${placeName(state.status.proxy)}.` : "");
  $("#mode-recommended").classList.toggle("current", mode.kind === "recommended");
  $("#mode-fastest").classList.toggle("current", mode.kind === "fastest");

  $("#serverlist-note").textContent = state.firefoxVersion ? `Server list as Firefox ${state.firefoxVersion} (the latest) sees it; updated automatically.` : "";
  $("#ping-note").textContent = state.pingedAt
    ? `Real delay tested ${relative(state.pingedAt)}: the time to reach www.google.com through each server with the active account, so it covers the whole path to the exit. Test real delay checks every server.`
    : "Test real delay to compare the servers. Each one is tested through the tunnel with the active account (the proxy must be running); this takes from a few seconds to a minute.";

  const query = $("#location-search").value.trim().toLowerCase();
  // Every location is listed: Mozilla's servers accept every account on
  // all of them, including those its server list marks locked.
  let rows = state.locations.filter((l) => (!query || l.name.toLowerCase().includes(query) || l.code.toLowerCase().includes(query)));
  rows = rows.slice().sort((a, b) => {
    if (state.sort === "latency") {
      const pa = a.ping_ms || Infinity;
      const pb = b.ping_ms || Infinity;
      if (pa !== pb) return pa - pb;
    }
    if (a.recommended !== b.recommended) return a.recommended ? -1 : 1;
    return a.name.localeCompare(b.name);
  });
  const measured = state.locations.filter((l) => l.ping_ms).map((l) => l.ping_ms);
  const worst = Math.max(1, ...measured);
  const best = measured.length ? Math.min(...measured) : 0;

  const body = $("#location-table tbody");
  body.replaceChildren();
  if (rows.length === 0) {
    body.append(el("tr", {}, el("td", { colspan: "4", class: "muted", text: state.locations.length ? "No location matches." : "The server list is not loaded yet." })));
    return;
  }
  let rank = 0;
  for (const loc of rows) {
    const isCurrent = loc.code === currentCode;
    let latency;
    if (loc.ping_ms) {
      rank++;
      const bar = el("div", { class: loc.ping_ms > best * 2.5 ? "slow" : loc.ping_ms > best * 1.5 ? "mid" : "" });
      bar.style.width = Math.max(4, (loc.ping_ms / worst) * 100).toFixed(0) + "%";
      latency = el("div", { class: "latency" },
        state.sort === "latency" ? el("span", { class: "rank", text: "#" + rank }) : null,
        el("div", { class: "latency-bar" }, bar),
        el("span", { class: "latency-ms", text: `${loc.ping_ms} ms` }));
    } else {
      // A location that did not answer is grey, not red: nothing is broken
      // here; the reason is on hover.
      latency = el("span", { class: "muted small", text: loc.ping_error ? "No answer" : "not tested", title: loc.ping_error || "" });
    }
    const action = isCurrent
      ? el("span", { class: "chip active", style: "background:var(--ok); color:#000; font-weight:700;", text: "فعال / Active" })
      : button("اتصال / Connect", () => chooseLocation(loc.code, locationName(loc)), { cls: "btn sm primary" });
    const rowEl = el("tr", { class: isCurrent ? "current" : "", style: "cursor:pointer;", title: isCurrent ? "سرور فعال" : `کلیک برای اتصال به ${locationName(loc)}` },
      el("td", {}, el("div", { class: "loc" }, flag(loc.code, loc.recommended), el("div", { class: "loc-name", text: locationName(loc) }))),
      el("td", { class: "hide-sm mono muted", text: loc.server || "" }),
      el("td", {}, latency),
      el("td", { class: "actions-cell" }, action),
    );
    rowEl.addEventListener("click", (e) => {
      if (e.target.closest("button") || isCurrent) return;
      chooseLocation(loc.code, locationName(loc));
    });
    body.append(rowEl);
  }
}

async function chooseLocation(country, label) {
  try {
    await api("POST", "/api/location", { country });
    toast(`Server set: ${label}. The proxy restarts.`);
    state.settings = null;
    await loadLocations();
    setTimeout(() => loadStatus().then(renderLocations).catch(reportError), 1500);
  } catch (error) { reportError(error); }
}

$("#measure").addEventListener("click", async (event) => {
  const node = event.currentTarget;
  const codes = state.locations.map((l) => l.code);
  if (codes.length === 0) { toast("هیچ سروری برای تست یافت نشد", true); return; }
  if (state.accounts && state.accounts.length === 0) {
    toast("برای تست پینگ سرورها، ابتدا باید از تب Accounts یک اکانت اضافه کنید", true);
    return;
  }
  try {
    toast(`در حال تست پینگ ${codes.length} سرور... لطفاً کمی صبر کنید`);
    const result = await busy(node, `تست پینگ ${codes.length}...`, () => api("POST", "/api/locations/ping", { codes }));
    const answered = (result.locations || []).filter((l) => l.ping_ms);
    await loadLocations();
    toast(answered.length ? `تست پینگ کامل شد: ${answered.length} سرور پاسخ دادند. سریع‌ترین: ${locationName(answered[0])} (${answered[0].ping_ms} میلی‌ثانیه)` : "هیچ سروری در این لحظه پاسخ نداد", answered.length === 0);
  } catch (error) {
    if (error.message && error.message.includes("no enabled accounts")) {
      toast("ابتدا باید حداقل یک اکانت فایرفاکس در تب Accounts اضافه کنید", true);
    } else {
      reportError(error);
    }
  }
});

$("#mode-recommended").addEventListener("click", () => chooseLocation("", "Auto (recommended)"));
$("#mode-fastest").addEventListener("click", () => chooseLocation("fastest", "Auto (fastest)"));
$("#location-search").addEventListener("input", () => renderLocations());
for (const seg of document.querySelectorAll(".seg[data-sort]")) {
  seg.addEventListener("click", () => {
    state.sort = seg.dataset.sort;
    for (const other of document.querySelectorAll(".seg[data-sort]")) other.classList.toggle("active", other === seg);
    renderLocations();
  });
}

// --------------------------------------------------------------- sign-in

const STEP_INPUT = {
  need_email_code: "Verification code",
  need_totp: "Authenticator code",
  need_unblock_code: "Unblock code",
  need_captcha: "Characters in the image",
};

// signInAgain re-signs an account with its stored password, so the dialog
// only asks for what Mozilla requests (a code); without a stored password
// it asks for the password as usual.
async function signInAgain(account) {
  if (!account.has_password) {
    openSignIn(account.email);
    return;
  }
  openSignIn(account.email);
  try {
    const view = await api("POST", "/api/signin", { account_id: account.id });
    renderSignIn(view);
    pollSignIn(view.id);
  } catch (error) {
    $("#signin-error").textContent = error.message;
  }
}

// showSignInStart shows the email and password fields (true) or a step
// of the sign-in. The hidden part's fields are disabled: a hidden required
// field blocks the form's submit without a word (the browser cannot focus
// it to complain), and the password is empty in a step, since it is
// cleared once sent and "Sign in again" never asks for it.
function showSignInStart(start) {
  $("#signin-start").hidden = !start;
  $("#signin-step").hidden = start;
  for (const input of $("#signin-start").querySelectorAll("input")) input.disabled = !start;
}

function openSignIn(email = "") {
  const dialog = $("#signin-dialog");
  const form = $("#signin-form");
  form.reset();
  form.email.value = email;
  state.signin = null;
  showSignInStart(true);
  $("#signin-error").textContent = "";
  $("#signin-submit").textContent = "Sign in";
  $("#signin-submit").hidden = false;
  $("#signin-submit").disabled = false;
  $("#signin-cancel").textContent = "Cancel";
  $("#signin-warning").hidden = !(state.status && state.status.dashboard.plaintext_over_network && !["localhost", "127.0.0.1", "[::1]"].includes(location.hostname));
  hideSecrets(dialog);
  dialog.showModal();
  (email ? form.password : form.email).focus();
}

function renderSignIn(view) {
  state.signin = view;
  showSignInStart(false);
  const message = $("#signin-message");
  const captcha = $("#signin-captcha");
  const label = $("#signin-input-label");
  const submit = $("#signin-submit");
  const form = $("#signin-form");
  // What went wrong shows apart from the instruction, in red.
  $("#signin-error").textContent = view.error || "";
  captcha.hidden = true;
  label.hidden = true;
  submit.hidden = false;
  submit.disabled = false;

  switch (view.step) {
    case "working":
      message.replaceChildren(el("span", { class: "spinner" }), el("span", { text: view.message || "Working…" }));
      submit.hidden = true;
      break;
    case "need_email_link":
      message.textContent = view.message;
      submit.textContent = "I opened the link";
      break;
    case "done":
      message.replaceChildren(el("span", { class: "chip ok", text: "Added" }), el("span", { text: "The account joins the rotation at the end of the list." }));
      submit.hidden = true;
      $("#signin-cancel").textContent = "Close";
      loadAccounts().catch(reportError);
      loadStatus().catch(reportError);
      break;
    case "failed":
    case "cancelled":
      message.textContent = view.message;
      submit.textContent = "Try again";
      break;
    default:
      if (STEP_INPUT[view.step]) {
        message.textContent = view.message;
        $("#signin-input-caption").textContent = STEP_INPUT[view.step];
        label.hidden = false;
        form.value.value = "";
        if (view.step === "need_captcha" && view.captcha && view.captcha.startsWith("data:image/")) {
          captcha.src = view.captcha;
          captcha.hidden = false;
        }
        submit.textContent = "Continue";
        setTimeout(() => form.value.focus(), 0);
      }
  }
}

async function pollSignIn(id) {
  while (state.signin && state.signin.id === id && $("#signin-dialog").open) {
    let view;
    try { view = await api("GET", `/api/signin/${encodeURIComponent(id)}`); } catch (error) { reportError(error); return; }
    const changed = view.step !== state.signin.step || view.message !== state.signin.message || view.captcha !== state.signin.captcha;
    if (changed) renderSignIn(view);
    if (["done", "failed", "cancelled"].includes(view.step)) return;
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
}

$("#add-account").addEventListener("click", () => openSignIn());

$("#signin-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.target;
  const current = state.signin;
  $("#signin-submit").disabled = true;
  try {
    if (!current || current.step === "failed" || current.step === "cancelled") {
      if (current) { openSignIn(current.email); return; }
      const view = await api("POST", "/api/signin", { email: form.email.value, password: form.password.value });
      form.password.value = "";
      renderSignIn(view);
      pollSignIn(view.id);
      return;
    }
    const value = current.step === "need_email_link" ? "continue" : form.value.value.trim();
    if (!value) { $("#signin-submit").disabled = false; return; }
    const view = await api("POST", `/api/signin/${encodeURIComponent(current.id)}`, { value });
    renderSignIn(view);
  } catch (error) {
    $("#signin-error").textContent = error.message;
    $("#signin-submit").disabled = false;
  }
});

$("#signin-cancel").addEventListener("click", async () => {
  const current = state.signin;
  if (current && !["done", "failed", "cancelled"].includes(current.step)) {
    try { await api("DELETE", `/api/signin/${encodeURIComponent(current.id)}`); } catch { /* ignore */ }
  }
  state.signin = null;
  $("#signin-dialog").close();
});

// ------------------------------------------------------------------ logs

function appendLog(entry) {
  if (state.logs.length && entry.id <= state.logs[state.logs.length - 1].id) return;
  state.logs.push(entry);
  if (state.logs.length > 2000) state.logs.splice(0, state.logs.length - 2000);
  if (state.view === "logs" && logVisible(entry)) {
    const list = $("#log-list");
    list.append(logRow(entry));
    while (list.childElementCount > 2000) list.firstElementChild.remove();
    if ($("#log-follow").checked) list.scrollTop = list.scrollHeight;
  }
  if (state.view === "overview") renderRecentLog();
}

function logVisible(entry) {
  const min = LEVELS[$("#log-level").value] ?? 1;
  if ((LEVELS[entry.level] ?? 1) < min) return false;
  const query = $("#log-search").value.trim().toLowerCase();
  return !query || entry.message.toLowerCase().includes(query);
}

function logRow(entry, short = false) {
  const time = new Date(entry.time);
  const stamp = short
    ? time.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false })
    : time.toLocaleString(undefined, { month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false });
  return el("div", { class: "log-row", title: short ? entry.message : undefined },
    el("span", { class: "log-time", text: stamp }),
    el("span", { class: "log-level " + entry.level, text: entry.level }),
    el("span", { class: "log-msg", text: entry.message }));
}

function renderLogs(scroll = false) {
  const list = $("#log-list");
  list.replaceChildren(...state.logs.filter(logVisible).map((entry) => logRow(entry)));
  if (scroll || $("#log-follow").checked) list.scrollTop = list.scrollHeight;
}

function renderRecentLog() {
  const recent = state.logs.filter((e) => e.level !== "DEBUG").slice(-8);
  const box = $("#recent-log");
  box.replaceChildren(...(recent.length ? recent.map((entry) => logRow(entry, true)) : [el("p", { class: "muted", text: "No activity yet." })]));
}

async function startLogs() {
  const data = await api("GET", "/api/logs");
  state.logs = data.entries || [];
  renderLogs(true);
  renderRecentLog();
  if (state.logSource) state.logSource.close();
  const source = new EventSource("/api/logs/stream");
  source.onmessage = (event) => {
    try { appendLog(JSON.parse(event.data)); } catch { /* ignore */ }
  };
  source.onerror = () => {
    // The browser reconnects by itself; reload the buffer once it does.
    source.onopen = async () => {
      try {
        const after = state.logs.length ? state.logs[state.logs.length - 1].id : 0;
        const missed = await api("GET", `/api/logs?after=${after}`);
        (missed.entries || []).forEach(appendLog);
      } catch { /* ignore */ }
    };
  };
  state.logSource = source;
}

$("#log-level").addEventListener("change", () => renderLogs());
$("#log-search").addEventListener("input", () => renderLogs());
$("#log-clear").addEventListener("click", () => { state.logs = []; renderLogs(); renderRecentLog(); });

// -------------------------------------------------------------- settings

const DNS_PRESETS = {
  system: [],
  auto: ["https://1.1.1.1/dns-query", "https://8.8.8.8/dns-query", "https://9.9.9.9/dns-query"],
  cloudflare: ["https://1.1.1.1/dns-query", "https://1.0.0.1/dns-query"],
  google: ["https://8.8.8.8/dns-query", "https://8.8.4.4/dns-query"],
  quad9: ["https://9.9.9.9/dns-query", "https://149.112.112.112/dns-query"],
  cloudflare_dot: ["tls://1.1.1.1", "tls://1.0.0.1"],
};

function dnsPresetFor(servers) {
  const key = JSON.stringify(servers || []);
  return Object.keys(DNS_PRESETS).find((name) => JSON.stringify(DNS_PRESETS[name]) === key) || "custom";
}

function dnsServersFromForm() {
  const preset = $("#dns-preset").value;
  if (preset !== "custom") return DNS_PRESETS[preset];
  return $("#dns-custom").value.split(/[\s,]+/).map((s) => s.trim()).filter(Boolean);
}

function renderDNSFields(servers) {
  const preset = dnsPresetFor(servers);
  $("#dns-preset").value = preset;
  $("#dns-custom").value = (servers || []).join("\n");
  $("#dns-custom-field").hidden = preset !== "custom";
  $("#dns-test-result").replaceChildren();
}

$("#dns-preset").addEventListener("change", (event) => {
  const custom = event.target.value === "custom";
  $("#dns-custom-field").hidden = !custom;
  if (custom && !$("#dns-custom").value.trim()) $("#dns-custom").value = DNS_PRESETS.auto.join("\n");
});

function dnsAnswer(addrs, error, ms, source) {
  if (error) return el("td", {}, el("span", { class: "latency-err", text: error }));
  return el("td", {},
    el("div", { class: "mono" }, (addrs || []).map((addr) => el("span", { text: addr }))),
    el("div", { class: "ms", text: `${ms} ms${source && source !== "system" ? " · " + source : ""}` }));
}

$("#dns-test").addEventListener("click", async (event) => {
  const servers = dnsServersFromForm();
  const box = $("#dns-test-result");
  try {
    const data = await busy(event.currentTarget, "Testing…", () => api("POST", "/api/dns/test", { servers }));
    const system = servers.length === 0;
    const head = el("tr", {}, el("th", { text: "Name" }), system ? null : el("th", { text: "Selected DNS" }), el("th", { text: "System DNS" }), el("th", { text: "" }));
    const rows = data.results.map((r) => el("tr", {},
      el("td", {}, el("div", { text: r.host }), el("div", { class: "ms", text: r.role })),
      system ? null : dnsAnswer(r.addrs, r.error, r.ms, r.source),
      dnsAnswer(r.system_addrs, r.system_error, r.system_ms),
      el("td", {}, r.filtered
        ? el("span", { class: "chip warn", title: "The network answered with a filtering address: its DNS is tampered with", text: "Filtered" })
        : null)));
    box.replaceChildren(el("table", { class: "dns-results" }, el("thead", {}, head), el("tbody", {}, rows)));
    const failed = data.results.filter((r) => (system ? r.system_error : r.error)).length;
    const filtered = data.results.filter((r) => r.filtered).length;
    toast(failed ? `${failed} of ${data.results.length} names failed`
      : filtered ? `Every name resolved; the network's DNS is filtered for ${filtered}` : "Every name resolved", failed > 0);
  } catch (error) {
    reportError(error);
  }
});

const INT_FIELDS = ["proxy.upstream_connections", "proxy.max_connections"];
const FLOAT_FIELDS = ["accounts.switch_threshold_percent"];

function getPath(object, path) {
  return path.split(".").reduce((value, key) => (value == null ? undefined : value[key]), object);
}

function setPath(object, path, value) {
  const keys = path.split(".");
  let target = object;
  for (const key of keys.slice(0, -1)) target = target[key];
  target[keys[keys.length - 1]] = value;
}

async function loadSettings() {
  const [settings, locations] = await Promise.all([
    api("GET", "/api/settings"),
    api("GET", "/api/locations").catch(() => ({ locations: [] })),
  ]);
  state.settings = settings;
  state.locations = locations.locations || [];
  const form = $("#settings-form");
  for (const input of form.querySelectorAll("input[name], select[name]")) {
    if (input.name === "location" || input.name === "dashboard_password") continue;
    let value = getPath(settings.config, input.name);
    if (input.type === "checkbox") input.checked = Boolean(value);
    else if (input.type === "radio") input.checked = String(value) === input.value;
    else {
      if (value != null) value = String(value);
      // A value the choices do not have (set in config.json) is kept.
      if (input.tagName === "SELECT" && value != null && ![...input.options].some((o) => o.value === value)) {
        input.append(el("option", { value, text: value }));
      }
      input.value = value ?? "";
    }
  }
  form.dashboard_password.value = "";
  hideSecrets(form);
  fillListen("proxy", settings.config.proxy.listen);
  fillListen("dash", settings.config.dashboard.listen);
  renderLocationSelect(settings.config.proxy);
  renderDNSFields(settings.config.dns && settings.config.dns.servers);
  fillRoutingFields(settings.config.routing || {});
  $("#system-proxy-row").hidden = !(state.status && state.status.system_proxy_supported);
  loadRoutingStatus().catch(() => {});
  // The folders, each with a copy button.
  const folder = (label, path) => el("div", { class: "folder" },
    el("span", { class: "set-ic" }, icon("folder")),
    el("span", { class: "folder-text" }, el("span", { class: "folder-label", text: label }), el("code", { text: path })),
    el("button", { type: "button", class: "btn icon sm ghost", title: `Copy the ${label.toLowerCase()}`, "aria-label": `Copy the ${label.toLowerCase()}`, onclick: () => copyText(path, label.toLowerCase()) }, icon("copy")));
  $("#data-dir").replaceChildren(...[
    settings.program_dir ? folder("Program folder", settings.program_dir) : null,
    folder("Data folder", settings.data_dir),
  ].filter(Boolean));
  $("#settings-error").textContent = "";
  state.settingsSnapshot = JSON.stringify(collectSettings().config);
  updateDirty();
}

// A listen address is edited as who may connect (a choice) and a port.
// An address the choices do not have (set in config.json) is kept.
function fillListen(prefix, listen) {
  const [host, port] = splitHostPort(listen || "");
  const select = $(`#${prefix}-host`);
  for (const option of select.querySelectorAll("option[data-custom]")) option.remove();
  if (![...select.options].some((o) => o.value === host)) {
    select.append(el("option", { value: host, "data-custom": "", text: host ? `${host} (from config.json)` : "All addresses (from config.json)" }));
  }
  select.value = host;
  $(`#${prefix}-port`).value = port;
}

function listenFromForm(prefix) {
  return hostPort($(`#${prefix}-host`).value, $(`#${prefix}-port`).value.trim());
}

// The settings as the form has them, ready for PUT /api/settings.
function collectSettings() {
  const form = $("#settings-form");
  const config = structuredClone(state.settings.config);
  for (const input of form.querySelectorAll("input[name], select[name]")) {
    if (input.name === "location" || input.name === "dashboard_password") continue;
    if (input.type === "radio" && !input.checked) continue;
    let value = input.type === "checkbox" ? input.checked : input.value.trim();
    if (INT_FIELDS.includes(input.name)) value = parseInt(value, 10) || 0;
    if (FLOAT_FIELDS.includes(input.name)) value = parseFloat(value) || 0;
    setPath(config, input.name, value);
  }
  config.proxy.listen = listenFromForm("proxy");
  config.dashboard.listen = listenFromForm("dash");
  config.dns = config.dns || {};
  config.dns.servers = dnsServersFromForm();
  routingFromForm(config);
  const locationChoice = form.location.value;
  if (locationChoice === "__server__") config.proxy.country = "";
  else { config.proxy.country = locationChoice; config.proxy.server = ""; }
  return { config, password: form.dashboard_password.value };
}

// The save bar shows while the form differs from the saved settings.
function updateDirty() {
  if (!state.settings || !state.settingsSnapshot) return;
  const { config, password } = collectSettings();
  const dirty = Boolean(password) || JSON.stringify(config) !== state.settingsSnapshot;
  $("#settings-form").classList.toggle("dirty", dirty);
}

$("#settings-form").addEventListener("input", updateDirty);
$("#settings-form").addEventListener("change", updateDirty);
$("#settings-discard").addEventListener("click", () => loadSettings().catch(reportError));

function renderLocationSelect(proxy) {
  const select = $("#location-select");
  select.replaceChildren(
    el("option", { value: "", text: "Auto (recommended)" }),
    el("option", { value: "fastest", text: "Auto (fastest: lowest real delay at each start)" }),
  );
  for (const loc of state.locations) {
    if (loc.recommended) continue;
    select.append(el("option", { value: loc.code, text: `${loc.name} (${loc.code})${loc.ping_ms ? ` — ${loc.ping_ms} ms` : ""}` }));
  }
  select.append(el("option", { value: "__server__", text: "Custom server…" }));
  let value = "";
  if (proxy.server) value = "__server__";
  else if (proxy.country) {
    const country = proxy.country.toLowerCase();
    const match = state.locations.find((l) => !l.recommended && (l.code.toLowerCase() === country || l.name.toLowerCase() === country));
    if (country === "fastest") value = "fastest";
    else if (country === "rec" || country === "recommended") value = "";
    else if (match) value = match.code;
    else {
      select.append(el("option", { value: proxy.country, text: proxy.country }));
      value = proxy.country;
    }
  }
  select.value = value;
  $("#server-field").hidden = value !== "__server__";
}

// The section being read is marked in the section list.
{
  const links = [...document.querySelectorAll(".settings-nav a")];
  const mark = (id) => {
    for (const link of links) link.classList.toggle("active", link.getAttribute("href") === `#${id}`);
  };
  const spy = new IntersectionObserver((entries) => {
    for (const entry of entries) if (entry.isIntersecting) mark(entry.target.id);
  }, { rootMargin: "0px 0px -65% 0px" });
  for (const link of links) {
    const target = document.querySelector(link.getAttribute("href"));
    if (target) spy.observe(target);
  }
  if (links[0]) mark(links[0].getAttribute("href").slice(1));
}

// The section links scroll without changing the page hash.
for (const link of document.querySelectorAll(".settings-nav a")) {
  link.addEventListener("click", (event) => {
    event.preventDefault();
    const target = document.querySelector(link.getAttribute("href"));
    if (target) target.scrollIntoView({ behavior: "smooth", block: "start" });
  });
}

$("#location-select").addEventListener("change", (event) => {
  $("#server-field").hidden = event.target.value !== "__server__";
});


$("#settings-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!state.settings) return;
  const { config, password } = collectSettings();
  $("#settings-error").textContent = "";
  if (!config.proxy.username !== !config.proxy.password) {
    $("#settings-error").textContent = "Set both the proxy username and password, or leave both empty.";
    return;
  }
  try {
    const result = await api("PUT", "/api/settings", { config, dashboard_password: password ? password : null });
    toast(result.proxy_restarted ? "Saved. The proxy restarts with the new settings." : "Settings saved");
    if (result.dashboard_moved) {
      const [host, port] = splitHostPort(config.dashboard.listen);
      const target = `${window.location.protocol}//${host === "0.0.0.0" || host === "" || host === "::" ? window.location.hostname : host}:${port}/app/`;
      toast(`The dashboard moved to ${target}`);
      setTimeout(() => { window.location.href = target; }, 1500);
      return;
    }
    await loadSettings();
    await loadStatus();
  } catch (error) {
    $("#settings-error").textContent = error.message;
  }
});

function splitHostPort(address) {
  const index = address.lastIndexOf(":");
  return [address.slice(0, index).replace(/^\[|\]$/g, ""), address.slice(index + 1)];
}

// ------------------------------------------------------------------- app

function stopPolling() {
  clearInterval(state.pollTimer);
  state.pollTimer = null;
  if (state.logSource) { state.logSource.close(); state.logSource = null; }
}

async function refresh() {
  try {
    await loadStatus();
    if (state.view === "accounts") await loadAccounts();
  } catch (error) { reportError(error); }
}

async function start() {
  try {
    if (!(await checkSession())) return;
  } catch (error) {
    reportError(error);
    return;
  }
  stopPolling();
  await refresh();
  startLogs().catch(reportError);
  state.pollTimer = setInterval(refresh, 6000);
  showView(state.view);
}

// ------------------------------------------------------------ phone menu

// On narrow screens the sidebar is a drawer behind the menu button: a page
// chosen, the backdrop, the close button, or Escape closes it.
const narrow = window.matchMedia("(max-width: 860px)");

function navOpen() { return $("#app").classList.contains("nav-open"); }

function setNavOpen(open) {
  $("#app").classList.toggle("nav-open", open);
  $("#nav-toggle").setAttribute("aria-expanded", String(open));
  document.body.classList.toggle("no-scroll", open);
  if (open) $(".nav-item.active")?.focus();
}

function closeNav() {
  if (!navOpen()) return;
  setNavOpen(false);
  if (narrow.matches) $("#nav-toggle").focus();
}

$("#nav-toggle").addEventListener("click", () => setNavOpen(!navOpen()));
$("#nav-close").addEventListener("click", closeNav);
$("#nav-backdrop").addEventListener("click", closeNav);
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && navOpen()) closeNav();
});
narrow.addEventListener("change", () => { if (!narrow.matches) setNavOpen(false); });

// The theme switch and Sign out sit in the top bar on narrow screens, in
// the page header otherwise; moving them keeps their handlers.
function placeHeadButtons() {
  const target = narrow.matches ? $("#bar-actions") : $("#head-actions");
  target.append($("#theme-toggle"), $("#logout"));
}
narrow.addEventListener("change", placeHeadButtons);
placeHeadButtons();

initTheme();
setupSecrets();
for (const item of document.querySelectorAll(".nav-item")) {
  item.addEventListener("click", () => {
    showView(item.dataset.view);
    if (navOpen()) setNavOpen(false);
  });
}
window.addEventListener("hashchange", () => {
  const name = location.hash.slice(1);
  if (PAGES[name]) showView(name);
});
if (PAGES[location.hash.slice(1)]) state.view = location.hash.slice(1);
document.getElementById("tun-toggle-btn")?.addEventListener("click", async () => {
  const current = !!(state.status && state.status.tun_active);
  const btn = document.getElementById("tun-toggle-btn");
  if (btn) btn.disabled = true;
  try {
    await api("POST", "/api/tun", { enabled: !current });
    await loadStatus();
  } catch (err) {
    alert("TUN Mode Error: " + (err.message || err));
  } finally {
    if (btn) btn.disabled = false;
  }
});


// ------------------------------------------------ Master Connect & Toggles
async function toggleMasterVPN() {
  const masterBtn = $("#master-connect-btn");
  const isRunning = Boolean(state.status && state.status.state && state.status.state.phase === "running");

  if (isRunning) {
    try {
      if (masterBtn) {
        masterBtn.className = "power-circle-btn state-connecting";
        const lbl = $("#master-btn-label");
        if (lbl) lbl.textContent = "STOPPING...";
      }

      // 1. Stop TUN if active
      if (state.status && state.status.tun_active) {
        await api("POST", "/api/tun", { enabled: false }).catch(() => {});
      }

      // 2. Clear Windows system proxy using dedicated endpoint
      await api("POST", "/api/system-proxy", { mode: "clear" }).catch(() => {});

      // 3. Turn off engine
      await api("POST", "/api/power", { on: false });

      // 4. Update UI immediately so button leaves yellow state right away
      if (state.status && state.status.state) {
        state.status.state.phase = "off";
        state.status.tun_active = false;
        renderStatus();
      }

      toast("اتصال قطع شد / Disconnected");
      setTimeout(() => loadStatus().catch(() => {}), 600);
    } catch (err) {
      reportError(err);
      loadStatus().catch(() => {});
    }
  } else {
    // Check accounts
    if (state.accounts && state.accounts.length === 0) {
      const accData = await api("GET", "/api/accounts").catch(() => ({ accounts: [] }));
      if (!accData.accounts || accData.accounts.length === 0) {
        toast("لطفاً ابتدا از تب Accounts حداقل یک اکانت فایرفاکس وارد نمایید", true);
        showView("accounts");
        return;
      }
      state.accounts = accData.accounts;
    }

    try {
      if (masterBtn) {
        masterBtn.className = "power-circle-btn state-connecting";
        const lbl = $("#master-btn-label");
        if (lbl) lbl.textContent = "CONNECTING...";
        const title = $("#master-status-title");
        if (title) title.textContent = "Connecting... / در حال اتصال";
        const pulse = $("#master-status-pulse");
        if (pulse) {
          pulse.style.background = "#f59e0b";
          pulse.style.boxShadow = "0 0 12px #f59e0b";
        }
      }

      const wantTun = $("#chk-tun-enabled") ? $("#chk-tun-enabled").checked : true;
      const wantSysProxy = $("#chk-sysproxy-enabled") ? $("#chk-sysproxy-enabled").checked : false;

      // 1. Turn on proxy engine
      await api("POST", "/api/power", { on: true });

      // 2. Set system proxy if checked
      if (wantSysProxy) {
        await api("POST", "/api/system-proxy", { mode: "set" }).catch(() => {});
      } else {
        await api("POST", "/api/system-proxy", { mode: "clear" }).catch(() => {});
      }

      // 3. Configure TUN mode preference in backend
      await api("POST", "/api/tun", { enabled: wantTun }).catch(() => {});
      toast("فیلترشکن در حال برقراری اتصال است...");

      setTimeout(() => loadStatus().catch(() => {}), 800);
    } catch (err) {
      reportError(err);
      loadStatus().catch(() => {});
    }
  }
}

// Master event listeners
$("#master-connect-btn")?.addEventListener("click", toggleMasterVPN);
$("#hero-server-pill")?.addEventListener("click", () => showView("locations"));

$("#chk-tun-enabled")?.addEventListener("change", async (e) => {
  const isRunning = Boolean(state.status && state.status.state && state.status.state.phase === "running");
  if (!isRunning) return;
  try {
    await api("POST", "/api/tun", { enabled: e.target.checked });
    toast(e.target.checked ? "TUN Mode فعال شد" : "TUN Mode غیرفعال شد");
    loadStatus().catch(reportError);
  } catch (err) {
    e.target.checked = !e.target.checked;
    reportError(err);
  }
});

$("#chk-sysproxy-enabled")?.addEventListener("change", async (e) => {
  const isRunning = Boolean(state.status && state.status.state && state.status.state.phase === "running");
  if (!isRunning) return;
  try {
    await api("POST", "/api/system-proxy", { mode: e.target.checked ? "set" : "clear" });
    toast(e.target.checked ? "System Proxy فعال شد" : "System Proxy غیرفعال شد");
    loadStatus().catch(reportError);
  } catch (err) {
    e.target.checked = !e.target.checked;
    reportError(err);
  }
});

$("#hero-quick-select")?.addEventListener("change", (e) => {
  const code = e.target.value;
  const name = e.target.options[e.target.selectedIndex]?.text || code;
  chooseLocation(code, name);
});


start();
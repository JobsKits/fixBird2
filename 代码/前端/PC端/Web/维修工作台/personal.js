/* Jobs · 账户私有工作日志与单次站内提醒；真实草稿只保留当前账户内存。 */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.WorkbenchPersonal = api;
})(globalThis, function () {
  "use strict";
  const LIMITS = { imageBytes: 8 * 1024 * 1024, videoBytes: 16 * 1024 * 1024, totalBytes: 32 * 1024 * 1024, files: 8, textChars: 20000 };
  const IMAGE = ["image/png", "image/jpeg", "image/gif", "image/webp"];
  const VIDEO = ["video/mp4", "video/webm", "video/quicktime"];
  const object = value => !!value && typeof value === "object" && !Array.isArray(value);
  const integer = value => Number.isSafeInteger(value) && value >= 0;
  const text = value => typeof value === "string";
  const time = value => text(value) && Number.isFinite(Date.parse(value));
  const safe = value => String(value == null ? "" : value).replace(/[&<>"']/g, c => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" })[c]);
  function validDate(value) {
    if (!text(value) || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
    const parsed = new Date(value + "T12:00:00Z");
    return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
  }
  function validMonth(value) { return text(value) && /^\d{4}-\d{2}$/.test(value) && validDate(value + "-01"); }
  function validZone(value) {
    if (!text(value)) return false;
    try { new Intl.DateTimeFormat("en", { timeZone: value }).format(0); return true; }
    catch (_) { return false; }
  }
  function validMedia(value) {
    return object(value) && text(value.id) && !!value.id && text(value.name) && !!value.name &&
      [...IMAGE, ...VIDEO].includes(value.mime) && integer(value.size) && value.size > 0 &&
      value.size <= (IMAGE.includes(value.mime) ? LIMITS.imageBytes : LIMITS.videoBytes);
  }
  function validLog(value) {
    return object(value) && validDate(value.date) && text(value.text) && [...value.text].length <= LIMITS.textChars &&
      integer(value.version) && text(value.updatedAt) && (!value.updatedAt || time(value.updatedAt)) &&
      Array.isArray(value.media) && value.media.length <= LIMITS.files && value.media.every(validMedia) &&
      new Set(value.media.map(item => item.id)).size === value.media.length &&
      value.media.reduce((sum, item) => sum + item.size, 0) <= LIMITS.totalBytes;
  }
  function validReminder(value, ownerId) {
    return object(value) && text(value.id) && !!value.id && value.ownerId === ownerId &&
      text(value.title) && [...value.title].length > 0 && [...value.title].length <= 200 &&
      text(value.body) && [...value.body].length <= 2000 && time(value.dueAt) &&
      validZone(value.timeZone) && ["pending", "notified", "done"].includes(value.status) &&
      integer(value.version) && value.version > 0 && time(value.createdAt) && time(value.updatedAt) &&
      (!value.notifiedAt || time(value.notifiedAt));
  }
  function handles(path) { return /^\/(?:work-logs(?:[/?]|$)|work-log-media\/|reminders(?:[/?]|$))/.test(path); }
  function validateResponse(path, options, result, actor) {
    if (!handles(path) || !actor || !actor.id) return false;
    const url = new URL(path, "https://personal.invalid"), route = url.pathname;
    const requestedOwner = url.searchParams.get("ownerId") || actor.id;
    if (route === "/work-logs") {
      if (url.searchParams.get("scope") === "all") {
        return object(result) && result.scope === "all" && result.ownerId === requestedOwner && validDate(result.today) && validZone(result.timeZone) &&
          result.readOnly === (requestedOwner !== actor.id) && result.page === Number(url.searchParams.get("page")) && result.pageSize === Number(url.searchParams.get("pageSize")) &&
          integer(result.total) && typeof result.hasMore === "boolean" && Array.isArray(result.items) && result.items.length <= result.pageSize &&
          result.items.every(item => validLog(item) && !item.deleted) && new Set(result.items.map(item => item.date)).size === result.items.length &&
          Array.isArray(result.owners) && result.owners.every(item => object(item) && text(item.id) && !!item.id && text(item.name) && text(item.role));
      }
      return object(result) && result.ownerId === requestedOwner && result.month === url.searchParams.get("month") &&
        validMonth(result.month) && validDate(result.today) && validZone(result.timeZone) &&
        result.readOnly === (requestedOwner !== actor.id) && Array.isArray(result.items) &&
        result.items.every(item => validLog(item) && item.date.startsWith(result.month + "-")) &&
        new Set(result.items.map(item => item.date)).size === result.items.length &&
        Array.isArray(result.owners) && result.owners.every(item => object(item) && text(item.id) && !!item.id && text(item.name) && text(item.role));
    }
    const log = route.match(/^\/work-logs\/(\d{4}-\d{2}-\d{2})(?:\/media)?$/);
    if (log) {
      if (options.method === "DELETE") return object(result) && result.ok === true && result.ownerId === actor.id && requestedOwner === actor.id && result.date === log[1] && result.deleted === true && integer(result.version) && result.version > 0;
      return validLog(result) && result.date === log[1] && result.ownerId === requestedOwner &&
        validDate(result.today) && validZone(result.timeZone) && result.readOnly === (requestedOwner !== actor.id);
    }
    if (route.startsWith("/work-log-media/")) {
      const encoded = result?.dataBase64;
      return validMedia(result) && result.id === decodeURIComponent(route.split("/")[2]) && text(result.ownerId) &&
        validDate(result.date) && text(encoded) && encoded.length === 4 * Math.ceil(result.size / 3) &&
        /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(encoded);
    }
    if (route === "/reminders" && (!options.method || options.method === "GET")) {
      return object(result) && time(result.serverNow) && Array.isArray(result.items) &&
        result.items.every(item => validReminder(item, actor.id)) &&
        new Set(result.items.map(item => item.id)).size === result.items.length;
    }
    if (/^\/reminders\/[^/]+\/fire$/.test(route)) {
      return object(result) && typeof result.claimed === "boolean" && validReminder(result.reminder, actor.id) &&
        result.reminder.id === decodeURIComponent(route.split("/")[2]) &&
        (!result.claimed || result.reminder.status === "notified");
    }
    if (options.method === "DELETE") {
      return object(result) && result.ok === true && result.ownerId === actor.id && result.id === decodeURIComponent(route.split("/")[2]);
    }
    return validReminder(result, actor.id) &&
      (route === "/reminders" || result.id === decodeURIComponent(route.split("/")[2]));
  }
  function localInput(value) {
    const date = value instanceof Date ? value : new Date(value);
    const pad = number => String(number).padStart(2, "0");
    return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate()) + "T" + pad(date.getHours()) + ":" + pad(date.getMinutes());
  }
  function inputToISO(value) {
    const parsed = new Date(value);
    if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value) || !Number.isFinite(parsed.getTime()) || localInput(parsed) !== value) return null;
    return parsed.toISOString();
  }
  function monthCells(month) {
    const first = new Date(month + "-01T12:00:00Z");
    const offset = (first.getUTCDay() + 6) % 7;
    return Array.from({ length: 42 }, (_, index) => new Date(first.getTime() + (index - offset) * 86400000).toISOString().slice(0, 10));
  }
  function shiftMonth(month, delta) {
    const date = new Date(month + "-01T12:00:00Z");
    date.setUTCMonth(date.getUTCMonth() + delta);
    const value = date.toISOString().slice(0, 7);
    return validMonth(value) ? value : month;
  }
  function createController(bridge, env = globalThis) {
    const doc = env.document;
    const $ = selector => doc.querySelector(selector);
    const ui = source => env.RepairI18n?.translate(source) || source;
    const now = () => env.now ? env.now() : Date.now();
    const urls = new Set(), drafts = new Map(), records = new Map(), mediaCache = new Map(), demoLogs = new Map();
    const notices = new Map(), shown = new Set(), deletedReminders = new Set();
    let context = null, ownerKey = "", generation = 0, monthSequence = 0, daySequence = 0, reminderSequence = 0, reminderDataRevision = 0;
    let month = "", selected = "", today = "", targetOwner = "", owners = [], readOnly = false, monthItems = [];
    let monthLoading = false, logLoading = false, reminderLoading = false, saving = false, polling = false;
    let logMessage = "", monthMessage = "", reminderMessage = "", reminders = [], timer = null, lastView = "", initialized = false, reminderSaving = false;
    let reminderDraft = { id: "", title: "", body: "", due: "", version: 0 }, reminderUnknown = null, reminderTimePicker = null;
    let historyItems = [], historyPage = 1, historyTotal = 0, historyHasMore = false, historyLoading = false, historyMessage = "", historySequence = 0;
    let deleteIntent = null, deleting = false;
    function locale() { return doc.documentElement?.lang || "zh-CN"; }
    function zone() { return context?.timeZone || Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC"; }
    function dateLabel(date, options = { dateStyle: "full" }) {
      try { return new Intl.DateTimeFormat(locale(), { ...options, timeZone: "UTC" }).format(new Date(date + "T12:00:00Z")); }
      catch (_) { return date; }
    }
    function todayInZone() {
      const parts = new Intl.DateTimeFormat("en-CA", { timeZone: zone(), year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(new Date(now()));
      return ["year", "month", "day"].map(type => parts.find(part => part.type === type).value).join("-");
    }
    function stamp() { return { generation, key: ownerKey, epoch: context?.epoch }; }
    function current(mark) {
      const latest = bridge.getContext();
      return mark.generation === generation && mark.key === ownerKey && mark.epoch === latest.epoch && identityKey(latest) === ownerKey;
    }
    function identityKey(value) {
      const actor = value.actor || {};
      return [value.mode, actor.id, actor.companyId || "", actor.authVersion || ""].join(":");
    }
    function logKey(owner = targetOwner, date = selected) { return owner + ":" + date; }
    function emptyLog(date = selected) { return { ownerId: targetOwner, date, text: "", media: [], version: 0, updatedAt: "", readOnly, today, timeZone: zone() }; }
    function selectedDraft() {
      const key = logKey();
      if (!drafts.has(key)) {
        const record = records.get(key) || emptyLog();
        drafts.set(key, { text: record.text, media: record.media.map(item => ({ ...item })), version: record.version, dirty: false, loaded: records.has(key), startedAt: new Date(now()).toISOString(), knownIds: new Set(record.media.map(item => item.id)) });
      }
      return drafts.get(key);
    }
    function makeURL(blob) {
      if (!env.URL?.createObjectURL) return "";
      const url = env.URL.createObjectURL(blob);
      urls.add(url);
      return url;
    }
    function discardURLs() {
      for (const url of urls) env.URL?.revokeObjectURL?.(url);
      urls.clear();
    }
    function reset() {
      closeReminderTimePicker(false);
      closeLogDelete(false);
      generation++; monthSequence++; daySequence++; reminderSequence++; historySequence++;
      discardURLs(); drafts.clear(); records.clear(); mediaCache.clear(); demoLogs.clear(); notices.clear(); shown.clear(); deletedReminders.clear();
      ownerKey = ""; context = null; targetOwner = ""; readOnly = false; owners = []; monthItems = []; reminders = [];
      logMessage = ""; monthMessage = ""; reminderMessage = ""; reminderDraft = { id: "", title: "", body: "", due: "", version: 0 }; reminderUnknown = null;
      monthLoading = false; logLoading = false; reminderLoading = false; saving = false; polling = false; initialized = false; reminderSaving = false;
      lastView = "";
      historyItems = []; historyPage = 1; historyTotal = 0; historyHasMore = false; historyLoading = false; historyMessage = ""; deleting = false;
      for (const id of ["#worklogsView", "#personalReminders", "#personalTips"]) if ($(id)) $(id).innerHTML = "";
    }
    async function request(path, options = {}, mark = stamp()) {
      const value = await bridge.request(path, options);
      if (!current(mark)) throw Object.assign(new Error("stale"), { stale: true });
      if (!validateResponse(path, options, value, context.actor)) throw new Error("invalid personal response");
      return value;
    }
    function query(owner = targetOwner) {
      const value = new URLSearchParams({ timeZone: zone() });
      if (owner !== context.actor.id) value.set("ownerId", owner);
      return value.toString();
    }
    function sourceNote() { return context.mode === "demo" ? ui("当前为独立合成演示，记录仅保留在内存中。") : ""; }
    function renderCalendar() {
      const host = $("#personalCalendar");
      if (!host || !month) return;
      const title = new Intl.DateTimeFormat(locale(), { year: "numeric", month: "long", timeZone: "UTC" }).format(new Date(month + "-01T12:00:00Z"));
      const week = Array.from({ length: 7 }, (_, index) => dateLabel("2026-11-" + String(index + 2).padStart(2, "0"), { weekday: "short" }));
      const dates = new Set(monthItems.map(item => item.date));
      const focusedDate = doc.activeElement?.dataset?.personalDate;
      const cells = monthCells(month), focusDate = cells.includes(selected) ? selected : month + "-01";
      host.innerHTML = '<div class="calendar-toolbar"><button type="button" class="button quiet" data-personal="previous-month">' + safe(ui("上个月")) + '</button><h2 data-no-translate>' + safe(title) + '</h2><button type="button" class="button quiet" data-personal="next-month">' + safe(ui("下个月")) + '</button></div>' +
        '<button type="button" class="button quiet calendar-today" data-personal="today">' + safe(ui("今天")) + '</button><div class="calendar-grid" role="group" aria-label="' + safe(title) + '">' +
        week.map(name => '<span data-no-translate>' + safe(name) + '</span>').join("") +
        cells.map(date => '<button type="button" class="calendar-day' + (date === today ? " is-today" : "") + (date.slice(0, 7) !== month ? " is-outside-month" : "") + (dates.has(date) ? " has-entry" : "") + '" data-personal-date="' + date + '" aria-pressed="' + (date === selected) + '" tabindex="' + (date === focusDate ? "0" : "-1") + '" aria-label="' + safe(dateLabel(date) + (dates.has(date) ? " · " + ui("有日志") : "")) + '"><span data-no-translate>' + Number(date.slice(8)) + '</span>' + (dates.has(date) ? '<span class="calendar-dot" aria-hidden="true"></span>' : "") + '</button>').join("") + '</div>' +
        (monthLoading || monthMessage ? '<p class="personal-feedback" role="status">' + safe(ui(monthLoading ? "正在加载日志…" : monthMessage)) + '</p>' : !monthItems.length ? '<div class="empty-state"><h3>' + safe(ui("暂无工作日志")) + '</h3><p>' + safe(ui(readOnly ? "只读查看" : "选择日期开始记录。")) + '</p></div>' : "") +
        '<button type="button" class="button quiet" data-personal="reload">' + safe(ui("重新加载")) + '</button>';
      if (focusedDate) doc.querySelector('[data-personal-date="' + focusedDate + '"]')?.focus({ preventScroll: true });
    }
    function renderLog() {
      const host = $("#personalEditor");
      if (!host || !context) return;
      const focused = doc.activeElement?.id === "personalLogText";
      const selection = focused ? [doc.activeElement.selectionStart, doc.activeElement.selectionEnd] : null;
      const draft = selectedDraft();
      const editable = !readOnly;
      const record = records.get(logKey()), isNewToday = !readOnly && selected === today && (!record?.version || record.deleted);
      const clock = isNewToday ? new Intl.DateTimeFormat(locale(), { hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23", timeZone: zone() }).format(new Date(draft.startedAt)) : "";
      const savedAt = !record?.deleted && record?.updatedAt ? new Intl.DateTimeFormat(locale(), { dateStyle: "full", timeStyle: "medium", timeZone: zone() }).format(new Date(record.updatedAt)) : "";
      host.innerHTML = '<div class="personal-editor-heading"><div><h2 id="personalLogDateHeading" tabindex="-1" data-no-translate>' + safe(dateLabel(selected) + (clock ? " " + clock : "")) + '</h2><p>' + safe(ui(readOnly ? "只读查看" : selected === today ? "今日备忘" : "工作记录")) + (clock ? ' · <span class="personal-log-time-kind">' + safe(ui("当前编辑时刻")) + '</span>' : "") + '</p>' + (savedAt ? '<time id="personalLogSavedAt" class="personal-log-saved-time" data-no-translate datetime="' + safe(record.updatedAt) + '">' + safe(ui("最近保存") + " · " + savedAt) + '</time>' : "") + '</div>' +
        (editable ? '<button class="button primary" type="button" data-personal="save-log"' + (saving || deleting || logLoading || context.mode === "server" && !draft.loaded ? " disabled" : "") + '>' + safe(ui("保存日志")) + '</button>' : '<span class="badge">' + safe(ui("仅本人可编辑")) + '</span>') + '</div>' +
        '<label class="form-field"><span>' + safe(ui("工作记录")) + '</span><textarea id="personalLogText" data-no-translate maxlength="20000"' + (editable && !deleting ? "" : " readonly") + ' placeholder="' + safe(ui("支持文字、图片和视频，也可粘贴剪贴板图片或视频。")) + '">' + safe(draft.text) + '</textarea></label>' +
        (editable ? '<div class="personal-media-actions"><label class="button"><span>' + safe(ui("添加图片或视频")) + '</span><input id="personalMediaInput" type="file" multiple accept="' + [...IMAGE, ...VIDEO].join(",") + '"' + (saving || deleting ? " disabled" : "") + ' hidden></label>' + (draft.dirty ? '<button type="button" class="button quiet" data-personal="discard-log"' + (saving || deleting ? " disabled" : "") + '>' + safe(ui("放弃草稿并重新加载")) + '</button>' : "") + '</div>' : "") +
        '<div id="personalLogMedia" class="personal-media-grid"></div><p class="personal-feedback" role="status">' + safe(ui(logLoading ? "正在加载日志…" : logMessage || (draft.dirty ? "日志尚未保存" : ""))) + '</p>' +
        (sourceNote() ? '<p class="personal-source">' + safe(sourceNote()) + '</p>' : "");
      renderMedia();
      if (focused) {
        const input = $("#personalLogText");
        input?.focus({ preventScroll: true });
        if (selection && typeof input?.setSelectionRange === "function") input.setSelectionRange(...selection);
      }
    }
    function updateLogTimeDisplay() {
      if (!context || !$("#personalLogDateHeading")) return;
      const record = records.get(logKey()), draft = selectedDraft();
      const isNewToday = !readOnly && selected === today && (!record?.version || record.deleted);
      const clock = isNewToday ? new Intl.DateTimeFormat(locale(), { hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23", timeZone: zone() }).format(new Date(draft.startedAt)) : "";
      $("#personalLogDateHeading").textContent = dateLabel(selected) + (clock ? " " + clock : "");
      if ($("#personalLogSavedAt") && record?.updatedAt) $("#personalLogSavedAt").textContent = ui("最近保存") + " · " + new Intl.DateTimeFormat(locale(), { dateStyle: "full", timeStyle: "medium", timeZone: zone() }).format(new Date(record.updatedAt));
    }
    function renderMedia() {
      const host = $("#personalLogMedia");
      if (!host) return;
      host.innerHTML = selectedDraft().media.map((item, index) => {
        const url = item.url || mediaCache.get(item.id);
        return '<figure class="personal-media-card">' + (url ? IMAGE.includes(item.mime)
          ? '<img src="' + safe(url) + '" alt="' + safe(item.name) + '" data-no-translate>'
          : '<video controls preload="metadata" src="' + safe(url) + '" aria-label="' + safe(item.name) + '" data-no-translate></video>'
          : '<button type="button" class="button quiet" data-personal="preview-media" data-media-index="' + index + '">' + safe(ui("预览附件")) + '</button>') +
          '<figcaption data-no-translate>' + safe(item.name) + '</figcaption><div class="action-list">' +
          (url ? '<a class="button quiet" href="' + safe(url) + '" download="' + safe(item.name) + '">' + safe(ui("下载附件")) + '</a>' : "") +
          (!readOnly ? '<button class="button quiet" type="button" data-personal="remove-media" data-media-index="' + index + '"' + (saving ? " disabled" : "") + '>' + safe(ui("移除附件")) + '</button>' : "") + '</div></figure>';
      }).join("");
    }
    function renderWorkspace() {
      const host = $("#worklogsView");
      if (!host || !context) return;
      host.innerHTML = '<div class="personal-owner-bar">' +
        (context.actor.role === "admin" && context.mode === "server" ? '<label class="form-field"><span>' + safe(ui("查看账户")) + '</span><select id="personalOwner">' + owners.map(owner => '<option value="' + safe(owner.id) + '"' + (owner.id === targetOwner ? " selected" : "") + ' data-no-translate>' + safe(owner.name || owner.id) + '</option>').join("") + '</select></label>' : "") +
        (readOnly ? '<p>' + safe(ui("只读查看")) + '</p>' : "") + '</div><div class="personal-workspace"><section class="panel personal-calendar" id="personalCalendar"></section><section class="panel personal-editor" id="personalEditor"></section></div><section id="personalLogHistory" class="panel personal-log-history"></section><dialog id="personalLogDeleteDialog" class="personal-log-delete-dialog" aria-labelledby="personalLogDeleteHeading"></dialog>';
      renderCalendar(); renderLog(); renderLogHistory();
    }
    function renderLogHistory() {
      const host = $("#personalLogHistory");
      if (!host || !context) return;
      const count = historyItems.length ? (historyPage - 1) * 20 + 1 + "–" + ((historyPage - 1) * 20 + historyItems.length) + " / " + historyTotal : "0 / " + historyTotal;
      host.innerHTML = '<div class="panel-heading"><h2>' + safe(ui("全部日志")) + '</h2><button class="button quiet" type="button" data-personal="reload-history">' + safe(ui("重新加载")) + '</button></div><div class="personal-log-list">' + (historyItems.length ? historyItems.map(item => '<article class="personal-log-row"><button type="button" id="personalLogOpen-' + item.date + '" class="personal-log-open" data-personal="open-log" data-log-date="' + item.date + '"><strong data-no-translate>' + safe(dateLabel(item.date)) + '</strong><span data-no-translate>' + safe(item.text.slice(0, 140) || ui("工作记录")) + '</span><small data-no-translate>' + safe(ui("最近保存") + " · " + new Intl.DateTimeFormat(locale(), { dateStyle: "medium", timeStyle: "medium", timeZone: zone() }).format(new Date(item.updatedAt))) + '</small></button>' + (!readOnly && targetOwner === context.actor.id ? '<button type="button" id="personalLogDelete-' + item.date + '" class="button quiet personal-log-delete" data-personal="delete-log" data-log-date="' + item.date + '"' + (saving || deleting ? ' disabled' : '') + '>' + safe(ui("删除日志")) + '</button>' : '') + '</article>').join("") : '<div class="empty-state"><h3>' + safe(ui(historyLoading ? "正在加载日志…" : "暂无工作日志")) + '</h3><p>' + safe(ui("选择日期开始记录。")) + '</p><button class="button" type="button" data-personal="reload-history">' + safe(ui("重新加载")) + '</button></div>') + '</div><p class="personal-feedback" role="status">' + safe(ui(historyMessage || (historyLoading ? "正在加载日志…" : ""))) + '</p><div class="personal-log-pagination"><button class="button quiet" type="button" data-personal="history-previous"' + (historyPage <= 1 || historyLoading ? ' disabled' : '') + '>' + safe(ui("上一页")) + '</button><span data-no-translate>' + count + '</span><button class="button quiet" type="button" data-personal="history-next"' + (!historyHasMore || historyLoading ? ' disabled' : '') + '>' + safe(ui("下一页")) + '</button></div>';
    }
    async function loadLogHistory(page = historyPage) {
      if (!context) return;
      const mark = stamp(), sequence = ++historySequence, owner = targetOwner, requestedPage = Math.max(1, page);
      historyLoading = true; historyMessage = ""; renderLogHistory();
      try {
        let items, total, hasMore;
        if (context.mode === "demo") {
          const all = [...demoLogs.values()].filter(item => item.ownerId === owner && !item.deleted).sort((a, b) => b.date.localeCompare(a.date));
          total = all.length; items = all.slice((requestedPage - 1) * 20, requestedPage * 20); hasMore = total > requestedPage * 20;
        } else {
          const result = await request("/work-logs?scope=all&page=" + requestedPage + "&pageSize=20&" + query(owner), {}, mark);
          if (!current(mark) || sequence !== historySequence || owner !== targetOwner) return;
          items = result.items; total = result.total; hasMore = result.hasMore;
        }
        if (!current(mark) || sequence !== historySequence || owner !== targetOwner) return;
        historyItems = items; historyPage = requestedPage; historyTotal = total; historyHasMore = hasMore;
        if (!items.length && requestedPage > 1) return loadLogHistory(requestedPage - 1);
      } catch (error) {
        if (current(mark) && !error.stale && sequence === historySequence && owner === targetOwner) historyMessage = "日志列表加载失败，请重试。";
      } finally {
        if (current(mark) && sequence === historySequence && owner === targetOwner) { historyLoading = false; renderLogHistory(); }
      }
    }
    function closeLogDelete(restoreFocus = true) {
      const intent = deleteIntent, dialog = $("#personalLogDeleteDialog");
      deleteIntent = null;
      if (dialog?.open) dialog.close();
      if (restoreFocus && intent && current(intent.mark)) ($("#personalLogDelete-" + intent.date) || $("#personalLogOpen-" + intent.date))?.focus({ preventScroll: true });
    }
    function openLogDelete(date) {
      if (!context || readOnly || targetOwner !== context.actor.id || saving || deleting) return;
      const item = historyItems.find(value => value.date === date), record = records.get(logKey(targetOwner, date));
      if (!item || record?.deleted) return;
      deleteIntent = { date, owner: targetOwner, version: Math.max(item.version, record?.version || 0), mark: stamp(), media: item.media };
      const dialog = $("#personalLogDeleteDialog");
      if (!dialog?.showModal) { deleteIntent = null; return; }
      dialog.innerHTML = '<h3 id="personalLogDeleteHeading">' + safe(ui("确认删除日志")) + '</h3><p data-no-translate>' + safe(dateLabel(date)) + '</p><p>' + safe(ui("删除后将移除该日期的日志、附件及未保存草稿，且无法恢复。")) + '</p><p id="personalLogDeleteError" class="personal-feedback" role="status"></p><div class="action-list"><button type="button" id="personalLogDeleteCancel" class="button quiet" data-personal="cancel-delete-log">' + safe(ui("取消")) + '</button><button type="button" id="personalLogDeleteConfirm" class="button danger" data-personal="confirm-delete-log">' + safe(ui("删除日志")) + '</button></div>';
      dialog.oncancel = event => { event.preventDefault(); if (!deleting) closeLogDelete(); };
      dialog.onclose = () => { if (deleteIntent && !deleting) closeLogDelete(); };
      dialog.showModal(); $("#personalLogDeleteCancel")?.focus({ preventScroll: true });
    }
    async function deleteLog() {
      const intent = deleteIntent;
      if (!intent || deleting || saving || !context || readOnly || intent.owner !== context.actor.id || targetOwner !== intent.owner || !current(intent.mark)) return;
      deleting = true;
      let deleted = false;
      $("#personalLogDeleteConfirm").disabled = true; $("#personalLogDeleteCancel").disabled = true; renderLog();
      try {
        const result = context.mode === "demo" ? { ok: true, ownerId: intent.owner, date: intent.date, deleted: true, version: intent.version + 1 } : await request("/work-logs/" + intent.date + "?" + query(intent.owner), { method: "DELETE", body: JSON.stringify({ version: intent.version, timeZone: zone() }) }, intent.mark);
        if (!current(intent.mark) || targetOwner !== intent.owner) return;
        const key = logKey(intent.owner, intent.date), draft = drafts.get(key), record = records.get(key);
        for (const item of [...intent.media, ...(record?.media || []), ...(draft?.media || [])]) {
          const url = item.url || mediaCache.get(item.id);
          if (url) { env.URL?.revokeObjectURL?.(url); urls.delete(url); } mediaCache.delete(item.id);
        }
        daySequence++; monthSequence++; historySequence++; logLoading = false; monthLoading = false;
        demoLogs.delete(key); drafts.delete(key);
        records.set(key, { ...emptyLog(intent.date), ownerId: intent.owner, version: result.version, deleted: true });
        monthItems = monthItems.filter(item => item.date !== intent.date);
        historyItems = historyItems.filter(item => item.date !== intent.date); historyTotal = Math.max(0, historyTotal - 1);
        deleted = true; closeLogDelete(false); if (selected === intent.date) logMessage = "日志已删除";
        renderCalendar(); renderLog(); renderLogHistory();
        loadLogHistory();
      } catch (error) {
        if (current(intent.mark) && !error.stale && targetOwner === intent.owner && $("#personalLogDeleteError")) $("#personalLogDeleteError").textContent = ui(error.status === 409 ? "日志已更新，请重新加载核对后删除" : "日志删除失败，请重新加载后重试。");
      } finally {
        if (current(intent.mark)) {
          deleting = false;
          if ($("#personalLogDeleteConfirm")) $("#personalLogDeleteConfirm").disabled = false;
          if ($("#personalLogDeleteCancel")) $("#personalLogDeleteCancel").disabled = false;
          renderLogHistory(); renderLog();
          if (deleted && context.view === "worklogs" && targetOwner === intent.owner) $("#personalLogDateHeading")?.focus({ preventScroll: true });
        }
      }
    }
    function formatReminder(item) {
      try { return new Intl.DateTimeFormat(locale(), { dateStyle: "medium", timeStyle: "short", timeZone: item.timeZone }).format(new Date(item.dueAt)) + " · " + item.timeZone; }
      catch (_) { return item.dueAt; }
    }
    function renderReminderList() {
      const host = $("#personalReminderList");
      if (!host) return;
      host.innerHTML = reminders.length ? reminders.map(item => '<article class="reminder-row"><div><h3 data-no-translate>' + safe(item.title) + '</h3>' +
        (item.body ? '<p data-no-translate>' + safe(item.body) + '</p>' : "") + '<p data-no-translate>' + safe(formatReminder(item)) + '</p><span class="badge">' + safe(ui({ pending: "待提醒", notified: "已提醒", done: "已完成" }[item.status])) + '</span></div><div class="action-list"><button type="button" class="button quiet" data-personal="edit-reminder" data-reminder="' + safe(item.id) + '">' + safe(ui("修改提醒")) + '</button>' +
        (item.status !== "done" ? '<button type="button" class="button quiet" data-personal="complete-reminder" data-reminder="' + safe(item.id) + '">' + safe(ui("标为完成")) + '</button>' : "") +
        '<button type="button" class="button quiet" data-personal="cancel-reminder" data-reminder="' + safe(item.id) + '">' + safe(ui("取消提醒")) + '</button></div></article>').join("") :
        '<div class="empty-state"><h3>' + safe(ui(reminderLoading ? "正在加载提醒…" : "暂无事件提醒")) + '</h3><p>' + safe(ui("到期提醒将在页面右下角显示。")) + '</p><button class="button" type="button" data-personal="reload-reminders">' + safe(ui("重新加载")) + '</button></div>';
    }
    function renderReminderForm() {
      const host = $("#personalReminderForm");
      if (!host) return;
      closeReminderTimePicker(false);
      host.innerHTML = '<h3>' + safe(ui(reminderDraft.id ? "修改提醒" : "新建提醒")) + '</h3><div class="reminder-form-grid"><label class="form-field"><span>' + safe(ui("提醒标题")) + '</span><input id="personalReminderTitle" data-no-translate maxlength="200" required value="' + safe(reminderDraft.title) + '"></label><div class="form-field"><span id="personalReminderTimeLabel">' + safe(ui("提醒时间")) + '</span><button id="personalReminderTimeTrigger" class="reminder-time-trigger" type="button" data-personal="open-reminder-time" aria-haspopup="dialog" aria-expanded="false" aria-controls="personalReminderTimeDialog" aria-labelledby="personalReminderTimeLabel personalReminderTimeValue"><span id="personalReminderTimeValue" data-no-translate>' + safe(reminderDraft.due ? reminderDraft.due.replace("T", " ") : ui("选择时间")) + '</span></button><input id="personalReminderDue" type="hidden" value="' + safe(reminderDraft.due) + '"><small data-no-translate>' + safe(zone()) + '</small></div><label class="form-field reminder-form-body"><span>' + safe(ui("补充说明")) + '</span><textarea id="personalReminderBody" data-no-translate maxlength="2000">' + safe(reminderDraft.body) + '</textarea></label></div><div class="action-list"><button class="button primary" type="submit">' + safe(ui("保存提醒")) + '</button>' + (reminderDraft.id ? '<button class="button quiet" type="button" data-personal="new-reminder">' + safe(ui("取消编辑")) + '</button>' : "") + '</div><dialog id="personalReminderTimeDialog" class="reminder-time-dialog" aria-labelledby="personalReminderTimeHeading"></dialog>';
    }
    // 时间面板只编辑临时副本，确认回填后仍须由主表单保存提醒。
    function captureReminderClock() {
      if (!reminderTimePicker) return;
      reminderTimePicker.hour = $("#personalReminderTimeHour")?.value || reminderTimePicker.hour;
      reminderTimePicker.minute = $("#personalReminderTimeMinute")?.value || reminderTimePicker.minute;
    }
    function renderReminderTimePicker() {
      const dialog = $("#personalReminderTimeDialog"), picker = reminderTimePicker;
      if (!dialog || !picker) return;
      const title = dateLabel(picker.month + "-01", { year: "numeric", month: "long" });
      const week = Array.from({ length: 7 }, (_, index) => dateLabel("2026-11-" + String(index + 2).padStart(2, "0"), { weekday: "short" }));
      const options = (count, selected) => Array.from({ length: count }, (_, index) => String(index).padStart(2, "0")).map(value => '<option value="' + value + '"' + (value === selected ? ' selected' : '') + '>' + value + '</option>').join("");
      const cells = monthCells(picker.month), focusDate = cells.includes(picker.date) ? picker.date : picker.month + "-01";
      dialog.innerHTML = '<div class="reminder-time-heading"><h3 id="personalReminderTimeHeading">' + safe(ui("提醒时间")) + '</h3><small data-no-translate>' + safe(zone()) + '</small></div><div class="reminder-time-controls"><button type="button" id="personalReminderTimePrevious" class="button quiet" data-personal="reminder-time-previous">' + safe(ui("上个月")) + '</button><strong data-no-translate>' + safe(title) + '</strong><button type="button" id="personalReminderTimeNext" class="button quiet" data-personal="reminder-time-next">' + safe(ui("下个月")) + '</button></div><div class="reminder-time-calendar" role="group" aria-label="' + safe(title) + '">' + week.map(name => '<span data-no-translate>' + safe(name) + '</span>').join("") + cells.map(date => '<button type="button" id="personalReminderTimeDay-' + date + '" data-personal="reminder-time-date" data-time-date="' + date + '" class="' + (date.slice(0, 7) !== picker.month ? 'outside-month' : '') + '" aria-pressed="' + (date === picker.date) + '" tabindex="' + (date === focusDate ? '0' : '-1') + '" aria-label="' + safe(dateLabel(date)) + '"><span data-no-translate>' + Number(date.slice(8)) + '</span></button>').join("") + '</div><div class="reminder-time-clock"><label class="form-field"><span>' + safe(ui("小时")) + '</span><select id="personalReminderTimeHour" data-no-translate>' + options(24, picker.hour) + '</select></label><label class="form-field"><span>' + safe(ui("分钟")) + '</span><select id="personalReminderTimeMinute" data-no-translate>' + options(60, picker.minute) + '</select></label></div><p id="personalReminderTimeError" class="reminder-time-error" role="status"></p><div class="reminder-time-actions"><button type="button" class="button quiet" data-personal="cancel-reminder-time">' + safe(ui("取消")) + '</button><button type="button" class="button primary" data-personal="confirm-reminder-time">' + safe(ui("确认时间")) + '</button></div>';
    }
    function closeReminderTimePicker(restoreFocus = true) {
      const picker = reminderTimePicker, dialog = $("#personalReminderTimeDialog");
      reminderTimePicker = null;
      if (dialog?.open) dialog.close();
      const trigger = $("#personalReminderTimeTrigger");
      trigger?.setAttribute("aria-expanded", "false");
      if (restoreFocus && picker && current(picker.mark)) trigger?.focus({ preventScroll: true });
    }
    function openReminderTimePicker() {
      if (!context || reminderTimePicker) return;
      captureReminderForm();
      const due = inputToISO(reminderDraft.due) ? reminderDraft.due : localInput(new Date(now()));
      reminderTimePicker = { date: due.slice(0, 10), month: due.slice(0, 7), hour: due.slice(11, 13), minute: due.slice(14, 16), mark: stamp(), formInstance: reminderDraft };
      renderReminderTimePicker();
      const dialog = $("#personalReminderTimeDialog");
      if (!dialog?.showModal) { closeReminderTimePicker(false); return; }
      dialog.oncancel = event => { event.preventDefault(); closeReminderTimePicker(); };
      dialog.onclose = () => { if (reminderTimePicker) closeReminderTimePicker(); };
      dialog.showModal();
      $("#personalReminderTimeTrigger")?.setAttribute("aria-expanded", "true");
      $("#personalReminderTimeDay-" + reminderTimePicker.date)?.focus({ preventScroll: true });
    }
    function confirmReminderTimePicker() {
      const picker = reminderTimePicker;
      if (!picker || !current(picker.mark) || picker.formInstance !== reminderDraft) { closeReminderTimePicker(false); return; }
      captureReminderClock();
      const due = picker.date + "T" + picker.hour + ":" + picker.minute;
      if (!inputToISO(due)) { $("#personalReminderTimeError").textContent = ui("请填写有效的提醒时间。"); return; }
      reminderDraft.due = due;
      $("#personalReminderDue").value = due;
      $("#personalReminderTimeValue").textContent = due.replace("T", " ");
      closeReminderTimePicker();
    }
    function renderReminders() {
      const host = $("#personalReminders");
      if (!host || !context) return;
      host.innerHTML = '<section class="panel personal-reminders"><div class="panel-heading"><div><h2>' + safe(ui("事件提醒")) + '</h2><p>' + safe(ui("到期提醒将在页面右下角显示。")) + '</p></div><button class="button quiet" type="button" data-personal="reload-reminders">' + safe(ui("重新加载")) + '</button></div><div class="personal-reminders-layout"><form id="personalReminderForm" class="reminder-form"></form><div id="personalReminderList" class="reminder-list"></div></div><p id="personalReminderFeedback" class="personal-feedback" role="status">' + safe(ui(reminderMessage)) + '</p>' + (sourceNote() ? '<p class="personal-source">' + safe(sourceNote()) + '</p>' : "") + '</section>';
      renderReminderForm(); renderReminderList();
      updateReminderBusy();
      if (reminderUnknown) host.insertAdjacentHTML("beforeend", '<button type="button" class="button quiet" data-personal="retry-reminder">' + safe(ui("重试原提醒保存")) + '</button>');
    }
    function updateReminderBusy() {
      const button = $("#personalReminderForm")?.querySelector?.('button[type="submit"]');
      if (button) { button.disabled = reminderSaving; button.setAttribute("aria-busy", String(reminderSaving)); }
    }
    function renderTips() {
      const host = $("#personalTips");
      if (!host) return;
      host.innerHTML = [...notices.values()].map(item => '<article class="personal-tip"><div><h3 data-no-translate>' + safe(item.title) + '</h3><p data-no-translate>' + safe(item.body || "") + '</p><small data-no-translate>' + safe(formatReminder(item)) + '</small></div><div class="action-list"><button type="button" class="button quiet" data-personal="view-reminder" data-reminder="' + safe(item.id) + '">' + safe(ui("查看提醒")) + '</button><button type="button" class="button quiet" data-personal="complete-reminder" data-reminder="' + safe(item.id) + '">' + safe(ui("标为完成")) + '</button><button type="button" class="button quiet" data-personal="close-tip" data-reminder="' + safe(item.id) + '">' + safe(ui("关闭提醒")) + '</button></div></article>').join("");
    }
    function applyLoadedLog(record, key = logKey()) {
      const existing = drafts.get(key);
      if ((records.get(key)?.version || 0) > record.version || (existing?.loaded && existing.version > record.version)) return;
      records.set(key, record);
      if (!existing || !existing.dirty) {
        drafts.set(key, { text: record.text, media: record.media.map(item => ({ ...item })), version: record.version, loaded: true, dirty: false, startedAt: existing?.startedAt || new Date(now()).toISOString(), knownIds: new Set(record.media.map(item => item.id)), revision: 0 });
      } else {
        existing.loaded = true;
        if (existing.unknown) {
          const intent = existing.unknown;
          const sameContents = intent.kind === "save" && record.text === intent.text &&
            JSON.stringify(record.media.map(item => item.id)) === JSON.stringify(intent.mediaIds);
          if (record.version === intent.version || sameContents) {
            existing.unknown = null;
            existing.version = record.version;
            existing.knownIds = new Set(record.media.map(item => item.id));
            if (sameContents && existing.text === intent.text && existing.media.every(item => !item.file) &&
                JSON.stringify(existing.media.map(item => item.id)) === JSON.stringify(intent.mediaIds)) {
              existing.dirty = false;
              logMessage = "日志已保存";
            }
          }
        }
        if (existing.version !== record.version) logMessage = "日志已更新，请重新加载核对后保存。";
      }
    }
    async function loadMonth() {
      if (!context) return;
      const mark = stamp(), sequence = ++monthSequence, requestedMonth = month, requestedOwner = targetOwner;
      monthLoading = true; monthMessage = ""; renderCalendar();
      try {
        if (context.mode === "demo") {
          monthItems = [...demoLogs.values()].filter(item => item.ownerId === requestedOwner && item.date.startsWith(requestedMonth + "-"));
          owners = [context.actor]; readOnly = false;
        } else {
          const result = await request("/work-logs?month=" + requestedMonth + "&" + query(requestedOwner), {}, mark);
          if (!current(mark) || sequence !== monthSequence || requestedMonth !== month || requestedOwner !== targetOwner) return;
          const merged = new Map(result.items.map(item => [item.date, item]));
          for (const record of records.values()) {
            if (record.ownerId === requestedOwner && record.deleted && record.date.startsWith(requestedMonth + "-")) {
              if ((merged.get(record.date)?.version || 0) <= record.version) merged.delete(record.date);
              continue;
            }
            if (record.ownerId === requestedOwner && record.version > 0 && record.date.startsWith(requestedMonth + "-") &&
                (merged.get(record.date)?.version || 0) < record.version) merged.set(record.date, record);
          }
          monthItems = [...merged.values()]; owners = result.owners.length ? result.owners : [context.actor];
          today = result.today; readOnly = result.readOnly;
        }
      } catch (error) {
        if (!current(mark) || error.stale || sequence !== monthSequence) return;
        monthMessage = "真实记录读取失败，草稿不会复制到演示数据。";
      } finally {
        if (current(mark) && sequence === monthSequence) {
          monthLoading = false; renderCalendar();
          const picker = $("#personalOwner");
          if (picker) picker.innerHTML = owners.map(owner => '<option value="' + safe(owner.id) + '"' + (owner.id === targetOwner ? " selected" : "") + ' data-no-translate>' + safe(owner.name || owner.id) + '</option>').join("");
        }
      }
    }
    async function loadDay(date = selected, { discard = false } = {}) {
      if (!validDate(date) || !context) return;
      selected = date;
      const key = logKey(), mark = stamp(), sequence = ++daySequence, requestedOwner = targetOwner;
      if (discard) drafts.delete(key);
      logLoading = true; logMessage = ""; renderCalendar(); renderLog();
      try {
        const record = context.mode === "demo" ? demoLogs.get(key) || emptyLog(date) :
          await request("/work-logs/" + date + "?" + query(requestedOwner), {}, mark);
        if (!current(mark) || sequence !== daySequence || requestedOwner !== targetOwner || date !== selected) return;
        readOnly = record.readOnly;
        today = record.today || today;
        applyLoadedLog(record, key);
      } catch (error) {
        if (!current(mark) || error.stale || sequence !== daySequence) return;
        logMessage = "真实记录读取失败，草稿不会复制到演示数据。";
      } finally {
        if (current(mark) && sequence === daySequence) { logLoading = false; renderCalendar(); renderLog(); }
      }
    }
    function fileMime(file) {
      if ([...IMAGE, ...VIDEO].includes(file.type)) return file.type;
      const extension = String(file.name || "").split(".").pop().toLowerCase();
      return ({ png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", gif: "image/gif", webp: "image/webp", mp4: "video/mp4", webm: "video/webm", mov: "video/quicktime" })[extension] || "";
    }
    async function addFiles(files) {
      if (!context || readOnly || saving || deleting) return;
      const draft = selectedDraft(), additions = [];
      for (const file of files) {
        const mime = fileMime(file);
        if (!mime) { logMessage = "无法识别该文件类型。"; renderLog(); return; }
        if (!integer(file.size) || file.size <= 0 || file.size > (IMAGE.includes(mime) ? LIMITS.imageBytes : LIMITS.videoBytes)) {
          logMessage = "附件超出大小限制。"; renderLog(); return;
        }
        additions.push({ name: file.name || (IMAGE.includes(mime) ? "clipboard-image" : "clipboard-video"), mime, size: file.size, file });
      }
      if (draft.media.length + additions.length > LIMITS.files) { logMessage = "每天最多添加8个附件。"; renderLog(); return; }
      if ([...draft.media, ...additions].reduce((sum, item) => sum + item.size, 0) > LIMITS.totalBytes) {
        logMessage = "每日附件总大小不能超过32MB。"; renderLog(); return;
      }
      for (const item of additions) item.url = makeURL(item.file);
      draft.media.push(...additions); draft.dirty = true; draft.revision = (draft.revision || 0) + 1;
      logMessage = "日志尚未保存"; renderLog();
    }
    function removeMedia(index) {
      if (readOnly || saving || deleting) return;
      const draft = selectedDraft(), item = draft.media[index];
      if (!item) return;
      draft.media.splice(index, 1);
      if (item.url) { env.URL?.revokeObjectURL?.(item.url); urls.delete(item.url); }
      draft.dirty = true; draft.revision = (draft.revision || 0) + 1; logMessage = "日志尚未保存"; renderMedia();
    }
    async function previewMedia(index) {
      const item = selectedDraft().media[index];
      if (!item || item.url || mediaCache.has(item.id)) return;
      const mark = stamp(), owner = targetOwner, date = selected;
      logMessage = "正在读取附件…"; renderLog();
      try {
        const result = await request("/work-log-media/" + encodeURIComponent(item.id), {}, mark);
        if (!current(mark) || owner !== targetOwner || date !== selected) return;
        if (records.get(logKey(owner, date))?.deleted || !selectedDraft().media.some(value => value.id === item.id)) return;
        if (result.ownerId !== owner || result.date !== date) throw new Error("media owner mismatch");
        const binary = (env.atob || globalThis.atob)(result.dataBase64);
        const bytes = Uint8Array.from(binary, character => character.charCodeAt(0));
        if (bytes.length !== item.size || result.mime !== item.mime) throw new Error("invalid media");
        mediaCache.set(item.id, makeURL(new (env.Blob || Blob)([bytes], { type: result.mime })));
        logMessage = ""; renderLog();
      } catch (error) {
        if (current(mark) && !error.stale && owner === targetOwner && date === selected) { logMessage = "附件读取失败，请重试。"; renderLog(); }
      }
    }
    async function base64(file) {
      const bytes = new Uint8Array(await file.arrayBuffer());
      let binary = "";
      for (let index = 0; index < bytes.length; index += 32768) binary += String.fromCharCode(...bytes.subarray(index, index + 32768));
      return (env.btoa || globalThis.btoa)(binary);
    }
    async function saveLog() {
      if (!context || readOnly || saving || deleting) return;
      const draft = selectedDraft(), key = logKey(), mark = stamp(), date = selected,
        owner = targetOwner, timeZone = zone(), writeQuery = query(targetOwner);
      if (context.mode === "server" && !draft.loaded) { logMessage = "真实记录读取失败，草稿不会复制到演示数据。"; renderLog(); return; }
      if (draft.unknown) { logMessage = "保存结果尚未确认，请重新加载核对。"; renderLog(); return; }
      if ([...draft.text].length > LIMITS.textChars) { logMessage = "日志正文最多20000个字符。"; renderLog(); return; }
      saving = true; logMessage = ""; renderLog();
      try {
        if (context.mode === "demo") {
          const record = { ...emptyLog(date), text: draft.text, media: draft.media.map((item, index) => ({ ...item, id: item.id || "demo-media-" + date + "-" + index })), version: draft.version + 1, updatedAt: new Date(now()).toISOString() };
          demoLogs.set(key, record);
          draft.version = record.version; draft.media = record.media; draft.dirty = false; draft.loaded = true;
          records.set(key, record); monthItems = [...demoLogs.values()].filter(item => item.date.startsWith(month + "-"));
        } else {
          for (const item of [...draft.media]) {
            if (!item.file) continue;
            const payload = { name: item.name, mime: item.mime, dataBase64: await base64(item.file), version: draft.version, timeZone };
            if (!current(mark)) return;
            draft.unknown = { kind: "media", version: draft.version };
            const result = await request("/work-logs/" + date + "/media?" + writeQuery, { method: "POST", body: JSON.stringify(payload) }, mark);
            const added = result.media.filter(media => !draft.knownIds.has(media.id));
            if (added.length !== 1) throw new Error("invalid upload result");
            Object.assign(item, added[0]); delete item.file;
            draft.version = result.version; draft.knownIds = new Set(result.media.map(media => media.id)); draft.unknown = null;
            records.set(key, result);
          }
          const payload = { text: draft.text, mediaIds: draft.media.map(item => item.id), version: draft.version, timeZone };
          const revision = draft.revision || 0;
          draft.unknown = { kind: "save", ...payload };
          const result = await request("/work-logs/" + date + "?" + writeQuery, { method: "PUT", body: JSON.stringify(payload) }, mark);
          records.set(key, result); draft.version = result.version; draft.knownIds = new Set(result.media.map(item => item.id)); draft.unknown = null;
          if ((draft.revision || 0) === revision) { draft.text = result.text; draft.dirty = false; }
          if (targetOwner === owner && date.startsWith(month + "-")) {
            const previous = monthItems.findIndex(item => item.date === date);
            if (previous >= 0) monthItems[previous] = result; else monthItems.push(result);
          }
        }
        if (logKey() === key) logMessage = draft.dirty ? "日志尚未保存" : "日志已保存";
        loadLogHistory();
      } catch (error) {
        if (!current(mark) || error.stale) return;
        if (error.status && error.status >= 400 && error.status < 500) draft.unknown = null;
        if (logKey() === key) logMessage = draft.unknown ? "保存结果尚未确认，请重新加载核对。" : "保存未完成，草稿仅保留在当前账号内存中。";
      } finally {
        if (current(mark)) { saving = false; renderCalendar(); renderLog(); }
      }
    }
    function replaceReminder(item) {
      if (deletedReminders.has(item.id)) return null;
      const index = reminders.findIndex(record => record.id === item.id);
      if (index >= 0 && reminders[index].version > item.version) return reminders[index];
      if (index < 0) reminders.push(item); else reminders[index] = item;
      reminders.sort((left, right) => left.dueAt.localeCompare(right.dueAt));
      return item;
    }
    function acceptReminderSave(item, intent) {
      if (reminderUnknown === intent) reminderUnknown = null;
      reminderDataRevision++;
      const latest = replaceReminder(item);
      if (!latest || latest.version > item.version || reminderDraft !== intent.formInstance) { renderReminderList(); return; }
      const unchanged = reminderDraft.title === intent.title && reminderDraft.body === intent.body && reminderDraft.due === intent.due;
      reminderDraft = unchanged ? { id: "", title: "", body: "", due: "", version: 0 } : { ...reminderDraft, id: item.id, version: item.version };
      reminderMessage = unchanged ? "提醒已保存" : "提醒尚未保存";
      renderReminders();
    }
    function reconcileReminderSave(items) {
      const intent = reminderUnknown;
      if (!intent) return;
      const candidates = items.filter(item => (intent.id ? item.id === intent.id : !intent.beforeIds.has(item.id)) &&
        item.title === intent.payload.title && item.body === intent.payload.body &&
        Date.parse(item.dueAt) === Date.parse(intent.payload.dueAt) && item.timeZone === intent.payload.timeZone);
      if (candidates.length === 1) acceptReminderSave(candidates[0], intent);
    }
    async function loadReminders() {
      if (!context) return;
      const mark = stamp(), sequence = ++reminderSequence, dataRevision = reminderDataRevision;
      reminderLoading = true; renderReminderList();
      try {
        if (context.mode === "server") {
          const result = await request("/reminders", {}, mark);
          if (!current(mark) || sequence !== reminderSequence || dataRevision !== reminderDataRevision) return;
          reminders = result.items.filter(item => !deletedReminders.has(item.id));
          reconcileReminderSave(reminders);
        }
        if (reminderUnknown) reminderMessage = "提醒保存结果尚未确认，请重新加载核对。";
        else if (reminderMessage !== "提醒已保存") reminderMessage = "";
        return true;
      } catch (error) {
        if (current(mark) && !error.stale && sequence === reminderSequence) reminderMessage = "提醒未保存，请重新加载后重试。";
        return false;
      } finally {
        if (current(mark) && sequence === reminderSequence) {
          reminderLoading = false; renderReminderList();
          const feedback = $("#personalReminderFeedback");
          if (feedback) feedback.textContent = ui(reminderMessage);
        }
      }
    }
    function captureReminderForm() {
      if ($("#personalReminderTitle")) reminderDraft.title = $("#personalReminderTitle").value;
      if ($("#personalReminderBody")) reminderDraft.body = $("#personalReminderBody").value;
      if ($("#personalReminderDue")) reminderDraft.due = $("#personalReminderDue").value;
    }
    async function saveReminder() {
      if (!context || reminderSaving) return;
      captureReminderForm();
      if (reminderUnknown) { reminderMessage = "提醒保存结果尚未确认，请重新加载核对。"; renderReminders(); return; }
      const unchangedTime = !!reminderDraft.id && reminderDraft.due === reminderDraft.initialDue;
      const dueAt = unchangedTime ? reminderDraft.originalDue : inputToISO(reminderDraft.due);
      if (!reminderDraft.title.trim()) { reminderMessage = "请填写提醒标题。"; renderReminders(); return; }
      if (!dueAt) { reminderMessage = "请填写有效的提醒时间。"; renderReminders(); return; }
      const mark = stamp(), payload = { title: reminderDraft.title, body: reminderDraft.body, dueAt,
        timeZone: unchangedTime ? reminderDraft.originalTimeZone : zone() };
      const editing = reminderDraft.id;
      const intent = { title: reminderDraft.title, body: reminderDraft.body, due: reminderDraft.due, formInstance: reminderDraft,
        id: editing, payload, beforeIds: new Set(reminders.map(item => item.id)) };
      reminderSaving = true;
      updateReminderBusy();
      try {
        let item;
        if (context.mode === "demo") {
          const previous = reminders.find(value => value.id === editing), timestamp = new Date(now()).toISOString();
          item = { ...payload, id: editing || "demo-reminder-" + now() + "-" + reminders.length, ownerId: context.actor.id, status: "pending", version: (previous?.version || 0) + 1, createdAt: previous?.createdAt || timestamp, updatedAt: timestamp };
        } else {
          if (editing) { payload.version = reminderDraft.version; payload.status = reminders.find(value => value.id === editing)?.status || "pending"; }
          intent.path = editing ? "/reminders/" + encodeURIComponent(editing) : "/reminders";
          intent.options = { method: editing ? "PUT" : "POST", body: JSON.stringify(payload) };
          reminderUnknown = intent;
          item = await request(intent.path, intent.options, mark);
        }
        if (!current(mark)) return;
        acceptReminderSave(item, intent);
        pollReminders();
      } catch (error) {
        if (current(mark) && !error.stale) {
          if (error.status >= 400 && error.status < 500 && reminderUnknown === intent) reminderUnknown = null;
          reminderMessage = reminderUnknown ? "提醒保存结果尚未确认，请重新加载核对。" : "提醒未保存，请重新加载后重试。"; renderReminders();
        }
      } finally {
        if (current(mark)) { reminderSaving = false; updateReminderBusy(); }
      }
    }
    async function completeReminder(id) {
      const item = reminders.find(value => value.id === id) || notices.get(id);
      if (!item || !context) return;
      const mark = stamp();
      try {
        const result = context.mode === "demo" ? { ...item, status: "done", version: item.version + 1 } :
          await request("/reminders/" + encodeURIComponent(id), { method: "PUT", body: JSON.stringify({ title: item.title, body: item.body, dueAt: item.dueAt, timeZone: item.timeZone, status: "done", version: item.version }) }, mark);
        if (!current(mark)) return;
        reminderDataRevision++; replaceReminder(result); notices.delete(id); renderReminderList(); renderTips();
      } catch (error) {
        if (current(mark) && !error.stale) { reminderMessage = "提醒未保存，请重新加载后重试。"; renderReminders(); }
      }
    }
    async function retryUnknownReminder() {
      if (!reminderUnknown || reminderSaving || !context) return;
      const intent = reminderUnknown, mark = stamp();
      const checked = await loadReminders();
      if (!checked || !current(mark) || reminderUnknown !== intent) return;
      reminderSaving = true;
      updateReminderBusy();
      try {
        const item = await request(intent.path, intent.options, mark);
        if (current(mark)) acceptReminderSave(item, intent);
      } catch (error) {
        if (current(mark) && !error.stale) {
          if (error.status >= 400 && error.status < 500 && reminderUnknown === intent) reminderUnknown = null;
          reminderMessage = reminderUnknown ? "提醒保存结果尚未确认，请重新加载核对。" : "提醒未保存，请重新加载后重试。";
          renderReminders();
        }
      } finally { if (current(mark)) { reminderSaving = false; updateReminderBusy(); } }
    }
    async function cancelReminder(id) {
      const item = reminders.find(value => value.id === id);
      if (!item || !context) return;
      const mark = stamp();
      try {
        if (context.mode === "server") await request("/reminders/" + encodeURIComponent(id), { method: "DELETE", body: JSON.stringify({ version: item.version }) }, mark);
        if (!current(mark)) return;
        reminderDataRevision++; deletedReminders.add(id); reminders = reminders.filter(value => value.id !== id); notices.delete(id); reminderMessage = "提醒已取消"; renderReminders(); renderTips();
      } catch (error) {
        if (current(mark) && !error.stale) { reminderMessage = "提醒未保存，请重新加载后重试。"; renderReminders(); }
      }
    }
    async function pollReminders() {
      if (!context || polling || doc.visibilityState === "hidden") return;
      const mark = stamp(), sequence = ++reminderSequence, dataRevision = reminderDataRevision;
      polling = true;
      try {
        let serverNow = now();
        if (context.mode === "server") {
          const result = await request("/reminders", {}, mark);
          if (!current(mark) || sequence !== reminderSequence || dataRevision !== reminderDataRevision) return;
          reminders = result.items.filter(item => !deletedReminders.has(item.id)); reconcileReminderSave(reminders); serverNow = Date.parse(result.serverNow);
        }
        for (const item of [...reminders]) {
          if (!current(mark)) return;
          if (item.status !== "pending" || Date.parse(item.dueAt) > serverNow) continue;
          const fireSequence = reminderSequence, fireRevision = reminderDataRevision;
          const result = context.mode === "demo" ? { claimed: true, reminder: { ...item, status: "notified", version: item.version + 1, notifiedAt: new Date(now()).toISOString() } } :
            await request("/reminders/" + encodeURIComponent(item.id) + "/fire", { method: "POST", body: JSON.stringify({ version: item.version }) }, mark);
          if (!current(mark) || fireSequence !== reminderSequence || fireRevision !== reminderDataRevision) return;
          reminderDataRevision++;
          const latest = replaceReminder(result.reminder);
          const key = result.reminder.id + ":" + result.reminder.version;
          if (result.claimed && latest && latest.version === result.reminder.version && latest.status === "notified" && !shown.has(key)) { shown.add(key); notices.set(item.id, result.reminder); renderTips(); }
        }
        renderReminderList();
      } catch (_) {
        // 认领结果未知不补弹；下次读服务端状态，不重放展示。
      } finally {
        if (current(mark)) polling = false;
      }
    }
    function sync() {
      const next = bridge.getContext(), key = identityKey(next);
      if (reminderTimePicker && (next.view !== "tasks" || !current(reminderTimePicker.mark))) closeReminderTimePicker(false);
      if (deleteIntent && (next.view !== "worklogs" || !current(deleteIntent.mark))) closeLogDelete(false);
      const reconnecting = !!context && !context.connected && next.connected;
      const epochChanged = !!context && context.epoch !== next.epoch;
      if (!next.actor?.id) { reset(); return; }
      if (key !== ownerKey) {
        reset(); context = next; ownerKey = key; targetOwner = next.actor.id;
        today = todayInZone(); selected = today; month = today.slice(0, 7); owners = [next.actor];
      } else if (context.epoch !== next.epoch) {
        generation++; monthSequence++; daySequence++; reminderSequence++; polling = false; saving = false; reminderSaving = false;
        monthLoading = false; logLoading = false; reminderLoading = false; context = next;
      } else context = next;
      if (!initialized) {
        initialized = true;
        if (!timer && env.setInterval) timer = env.setInterval(() => { sync(); pollReminders(); }, 15000);
        pollReminders();
      }
      if (context.view === "worklogs") {
        if (!$("#personalCalendar")) renderWorkspace();
        if (lastView !== "worklogs" || reconnecting || epochChanged) { loadMonth(); loadDay(selected); loadLogHistory(); }
      }
      if (context.view === "tasks") {
        if (!$("#personalReminderForm")) renderReminders();
        if (lastView !== "tasks" || reconnecting || epochChanged) loadReminders();
      }
      updateReminderBusy();
      lastView = context.view;
    }
    function destroy() { reset(); if (timer) env.clearInterval?.(timer); timer = null; }
    function editReminder(id) {
      const item = reminders.find(value => value.id === id) || notices.get(id);
      if (!item) return;
      reminderDraft = { id: item.id, title: item.title, body: item.body, due: localInput(item.dueAt), version: item.version,
        initialDue: localInput(item.dueAt), originalDue: item.dueAt, originalTimeZone: item.timeZone };
      if (bridge.navigate && context.view !== "tasks") bridge.navigate("tasks");
      renderReminders();
    }
    if (doc.addEventListener) {
      doc.addEventListener("click", event => {
        const button = event.target.closest?.("[data-personal],[data-personal-date],[data-reminder-title]");
        if (!button || !context) return;
        if (button.dataset.reminderTitle !== undefined) {
          reminderDraft = { id: "", title: button.dataset.reminderTitle, body: "", due: "", version: 0 };
          if (context.view !== "tasks") bridge.navigate?.("tasks");
          renderReminders(); return;
        }
        if (button.dataset.personalDate) {
          const date = button.dataset.personalDate;
          if (date.slice(0, 7) !== month) { month = date.slice(0, 7); loadMonth(); }
          loadDay(date); return;
        }
        const action = button.dataset.personal, id = button.dataset.reminder;
        if (action === "open-reminder-time") openReminderTimePicker();
        else if (action === "cancel-reminder-time") closeReminderTimePicker();
        else if (action === "confirm-reminder-time") confirmReminderTimePicker();
        else if (reminderTimePicker && ["reminder-time-date", "reminder-time-previous", "reminder-time-next"].includes(action)) {
          captureReminderClock();
          if (action === "reminder-time-date" && validDate(button.dataset.timeDate)) { reminderTimePicker.date = button.dataset.timeDate; reminderTimePicker.month = button.dataset.timeDate.slice(0, 7); }
          else reminderTimePicker.month = shiftMonth(reminderTimePicker.month, action === "reminder-time-previous" ? -1 : 1);
          renderReminderTimePicker();
          const focus = action === "reminder-time-date" ? "#personalReminderTimeDay-" + reminderTimePicker.date : action === "reminder-time-previous" ? "#personalReminderTimePrevious" : "#personalReminderTimeNext";
          $(focus)?.focus({ preventScroll: true });
        }
        else if (action === "previous-month" || action === "next-month") { month = shiftMonth(month, action === "previous-month" ? -1 : 1); loadMonth(); }
        else if (action === "today") { selected = today; month = today.slice(0, 7); loadMonth(); loadDay(today); }
        else if (action === "reload") { loadMonth(); loadDay(selected); loadLogHistory(); }
        else if (action === "reload-history") loadLogHistory();
        else if (action === "history-previous" && historyPage > 1 && !historyLoading) loadLogHistory(historyPage - 1);
        else if (action === "history-next" && historyHasMore && !historyLoading) loadLogHistory(historyPage + 1);
        else if (action === "open-log" && validDate(button.dataset.logDate)) {
          const date = button.dataset.logDate, mark = stamp(), owner = targetOwner;
          if (date.slice(0, 7) !== month) { month = date.slice(0, 7); loadMonth(); }
          loadDay(date).then(() => { if (current(mark) && targetOwner === owner && selected === date) $("#personalLogText")?.focus({ preventScroll: true }); });
        }
        else if (action === "delete-log") openLogDelete(button.dataset.logDate);
        else if (action === "cancel-delete-log" && !deleting) closeLogDelete();
        else if (action === "confirm-delete-log") deleteLog();
        else if (action === "save-log") saveLog();
        else if (action === "discard-log") loadDay(selected, { discard: true });
        else if (action === "preview-media") previewMedia(Number(button.dataset.mediaIndex));
        else if (action === "remove-media") removeMedia(Number(button.dataset.mediaIndex));
        else if (action === "reload-reminders") { loadReminders(); pollReminders(); }
        else if (action === "retry-reminder") retryUnknownReminder();
        else if (action === "edit-reminder" || action === "view-reminder") editReminder(id);
        else if (action === "complete-reminder" || action === "read-reminder") completeReminder(id);
        else if (action === "cancel-reminder") cancelReminder(id);
        else if (action === "close-tip") { notices.delete(id); renderTips(); }
        else if (action === "new-reminder") { reminderDraft = { id: "", title: "", body: "", due: "", version: 0 }; renderReminders(); }
      });
      doc.addEventListener("input", event => {
        if (event.target.id === "personalLogText" && !readOnly && !deleting) {
          const draft = selectedDraft(); draft.text = event.target.value; draft.dirty = true; draft.revision = (draft.revision || 0) + 1;
        }
        if (["personalReminderTitle", "personalReminderBody", "personalReminderDue"].includes(event.target.id)) captureReminderForm();
      });
      doc.addEventListener("change", event => {
        if (event.target.id === "personalMediaInput") addFiles(Array.from(event.target.files || []));
        if (event.target.id === "personalOwner" && context.actor.role === "admin") {
          closeLogDelete(false); historySequence++; historyItems = []; historyPage = 1; historyTotal = 0; historyHasMore = false; historyMessage = "";
          targetOwner = event.target.value; readOnly = targetOwner !== context.actor.id; monthItems = []; renderWorkspace(); loadMonth(); loadDay(selected); loadLogHistory();
        }
      });
      doc.addEventListener("submit", event => {
        if (event.target.id !== "personalReminderForm") return;
        event.preventDefault(); saveReminder();
      });
      doc.addEventListener("paste", event => {
        if (context?.view !== "worklogs" || readOnly) return;
        const files = Array.from(event.clipboardData?.items || []).filter(item => item.kind === "file" && [...IMAGE, ...VIDEO].includes(item.type)).map(item => item.getAsFile()).filter(Boolean);
        if (files.length) { event.preventDefault(); addFiles(files); }
      });
      doc.addEventListener("visibilitychange", () => { if (doc.visibilityState !== "hidden") { sync(); pollReminders(); } });
      doc.addEventListener("repair-locale-change", () => { if (context) { renderCalendar(); updateLogTimeDisplay(); renderLogHistory(); renderReminderList(); renderTips(); if (reminderTimePicker) { captureReminderClock(); renderReminderTimePicker(); } } });
      doc.addEventListener("keydown", event => {
        if (deleteIntent && event.key === "Escape") { event.preventDefault(); if (!deleting) closeLogDelete(); return; }
        if (reminderTimePicker) {
          if (event.key === "Escape") { event.preventDefault(); closeReminderTimePicker(); return; }
          const offset = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7 }[event.key];
          if (event.target.dataset?.timeDate && offset) {
            event.preventDefault(); captureReminderClock();
            const next = new Date(event.target.dataset.timeDate + "T12:00:00Z"); next.setUTCDate(next.getUTCDate() + offset);
            reminderTimePicker.date = next.toISOString().slice(0, 10); reminderTimePicker.month = reminderTimePicker.date.slice(0, 7);
            renderReminderTimePicker(); $("#personalReminderTimeDay-" + reminderTimePicker.date)?.focus({ preventScroll: true });
          }
          return;
        }
        const button = event.target.closest?.("[data-personal-date]");
        const offset = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7 }[event.key];
        if (!button || !offset) return;
        event.preventDefault();
        const next = new Date(button.dataset.personalDate + "T12:00:00Z");
        next.setUTCDate(next.getUTCDate() + offset);
        const date = next.toISOString().slice(0, 10);
        if (date.slice(0, 7) !== month) { month = date.slice(0, 7); loadMonth(); }
        loadDay(date);
        env.setTimeout?.(() => doc.querySelector('[data-personal-date="' + date + '"]')?.focus(), 0);
      });
    }
    env.addEventListener?.("online", () => { sync(); if (context?.view === "worklogs") { loadMonth(); loadDay(selected); } pollReminders(); });
    env.addEventListener?.("pagehide", destroy);
    env.addEventListener?.("pageshow", () => { sync(); pollReminders(); });
    return { sync, reset, destroy, loadMonth, loadDay, saveLog, addFiles, previewMedia, removeMedia, saveReminder, loadReminders, pollReminders, completeReminder, cancelReminder, retryUnknownReminder, loadLogHistory, deleteLog, getState: () => ({ context, month, selected, targetOwner, readOnly, logMessage, reminderMessage, reminderSaving, reminders, reminderDraft, historyItems, historyPage, historyTotal, historyMessage, deleting, notices: [...notices.values()], draft: context ? selectedDraft() : null }) };
  }
  return { handles, validateResponse, validDate, validMonth, validMedia, validLog, validReminder, localInput, inputToISO, monthCells, shiftMonth, createController, limits: LIMITS };
});

// Created by Jobs. 只翻译界面展示，业务字段、输入值和请求保持原文。
(() => {
  const languages = [
    ['zh-Hans', '简体中文'], ['zh-Hant', '繁體中文'], ['bo', 'བོད་ཡིག'],
    ['en', 'English'], ['ja', '日本語'], ['fr', 'Français'], ['es', 'Español'],
    ['de', 'Deutsch'], ['ru', 'Русский'], ['ko', '한국어']
  ];
  let locale = 'zh-Hans';
  try { locale = localStorage.getItem('repair-ui-locale') || locale; } catch {}
  if (!languages.some(([code]) => code === locale)) locale = 'zh-Hans';
  let messages = {};
  let keys = [];
  let queued = false;
  const textSources = new WeakMap();
  const attributeSources = new WeakMap();
  const skip = 'script,style,textarea,[data-no-translate],.order-title,.order-number,.order strong,.order p,.file-preview,pre';
  const staticSelectors = '[data-ui-l10n],h1,h2,h3,h4,nav button,button:not([data-order]),label,option,th,.badge,.metric-label,.metric-name,.cell-sub,.mobile-label,.next-task,.breadcrumbs,.source-badge,.muted,.workspace-caption,.sidebar-bottom,.page-heading p,.panel-heading p,.flow-panel p,.flow-step,.step-label,.empty-title,.empty-description,.empty-state,.connection-note,.section-title,.drawer-title,.field-label,.notice,#notice,#toast,.error,.hint,.login>a,.skip-link,.brand small,.metric small,.type-chip,.mini-flow,.attention-item strong,.attention-item>span:last-child,#tableSummary,.table-pagination,.list-pagination';
  const observer = new MutationObserver(() => schedule());

  function translate(source, template = false) {
    if (locale === 'zh-Hans') return source;
    const dictionary = messages[locale] || {};
    if (Object.hasOwn(dictionary, source)) return dictionary[source];
    const clean = source.trim();
    if (Object.hasOwn(dictionary, clean)) return source.replace(clean, dictionary[clean]);
    if (!template) return source;
    // Counts use explicit templates; short unit words never participate in arbitrary substring replacement.
    const pageSummary = clean.match(/^本页 (\d+) 条 \/ 共 (\d+) 张工单$/);
    if (pageSummary) return `${dictionary['当前：'] || 'Current:'} ${pageSummary[1]} / ${dictionary['共'] || 'Total'} ${pageSummary[2]} ${dictionary['工单'] || ''}`;
    const pagination = clean.match(/^按工单分页 · 共 (\d+) 张 · 第 (\d+) \/ (\d+) 页$/);
    if (pagination) return `${dictionary['工单'] || ''} · ${dictionary['共'] || 'Total'} ${pagination[1]} · ${dictionary['第'] || ''} ${pagination[2]} / ${pagination[3]} ${dictionary['页'] || ''}`;
    const orderPage = clean.match(/^共 (\d+) 条 · 第 (\d+) 页$/);
    if (orderPage) return `${dictionary['共'] || 'Total'} ${orderPage[1]} ${dictionary['工单'] || ''} · ${dictionary['第'] || ''} ${orderPage[2]} ${dictionary['页'] || ''}`;
    const used = keys.filter(key => key.length > 1 && clean.includes(key));
    if (!used.length) return source;
    const pattern = used.map(key => key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|');
    const matcher = new RegExp(pattern, 'g');
    // Marked UI labels may compose known labels; a remaining Han character means this is not a controlled template.
    if (/[\u3400-\u9fff]/.test(clean.replace(matcher, ''))) return source;
    return source.replace(matcher, match => dictionary[match]);
  }

  function ensurePicker() {
    if (document.querySelector('#repairLocale')) return;
    const host = document.querySelector('.topbar-actions')
      || document.querySelector('.workspace > .toolbar .actions')
      || document.querySelector('.login .brand');
    if (!host) return;
    const label = document.createElement('label');
    label.className = 'locale-control';
    label.dataset.noTranslate = '';
    const select = document.createElement('select');
    select.id = 'repairLocale';
    select.setAttribute('aria-label', translate('应用语言'));
    for (const [value, name] of languages) {
      const option = document.createElement('option');
      option.value = value;
      option.textContent = name;
      select.append(option);
    }
    select.value = locale;
    select.onchange = () => {
      locale = select.value;
      try { localStorage.setItem('repair-ui-locale', locale); } catch {}
      keys = Object.keys(messages[locale] || {}).sort((a, b) => b.length - a.length);
      document.documentElement.lang = locale === 'zh-Hans' ? 'zh-CN' : locale === 'zh-Hant' ? 'zh-TW' : locale;
      apply();
    };
    label.append(select);
    host.append(label);
  }

  function apply() {
    queued = false;
    observer.disconnect();
    ensurePicker();
    document.querySelector('#repairLocale')?.setAttribute('aria-label', translate('应用语言'));
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    let node;
    while ((node = walker.nextNode())) {
      if (!node.parentElement || node.parentElement.closest(skip)) continue;
      const staticHost = node.parentElement.closest(staticSelectors);
      if (!staticHost) continue;
      staticHost.dataset.uiL10n = ''; 
      let saved = textSources.get(node);
      if (!saved || node.nodeValue !== saved.applied) saved = { original: node.nodeValue, applied: node.nodeValue };
      if (node.parentElement.tagName === 'OPTION' && !node.parentElement.hasAttribute('value')) {
        node.parentElement.value = saved.original;
      }
      saved.applied = translate(saved.original, true);
      if (node.nodeValue !== saved.applied) node.nodeValue = saved.applied;
      textSources.set(node, saved);
    }
    for (const element of document.querySelectorAll('[placeholder],[aria-label],[title]')) {
      if (element.closest('[data-no-translate]')) continue;
      const saved = attributeSources.get(element) || {};
      for (const key of ['placeholder', 'aria-label', 'title']) {
        if (!element.hasAttribute(key)) continue;
        const current = element.getAttribute(key);
        if (!saved[key] || current !== saved[key].applied) saved[key] = { original: current };
        saved[key].applied = translate(saved[key].original);
        if (current !== saved[key].applied) element.setAttribute(key, saved[key].applied);
      }
      attributeSources.set(element, saved);
    }
    observer.observe(document.body, { subtree: true, childList: true, characterData: true });
  }

  function schedule() {
    if (!queued) { queued = true; requestAnimationFrame(apply); }
  }

  async function start() {
    const style = document.createElement('style');
    style.textContent = '.locale-control{margin:0;display:inline-flex;align-items:center;flex:none}.locale-control select{width:120px;min-height:44px;padding:8px 10px;border:1px solid var(--border,var(--line));border-radius:10px;background:var(--surface);color:var(--text,var(--ink));font-size:13px}.login .locale-control{margin-left:auto}.topbar-actions .locale-control{max-width:120px}@media(max-width:620px){.locale-control select{width:112px}.topbar-actions{gap:8px;flex-wrap:wrap}.topbar{height:auto;min-height:80px;padding-block:12px}.breadcrumbs{flex-shrink:0}}';
    document.head.append(style);
    try {
      const response = await fetch('/admin-font/ui-l10n.json');
      if (response.ok) messages = (await response.json()).messages || {};
    } catch { /* 翻译包不可用时保留可操作的源文界面。 */ }
    keys = Object.keys(messages[locale] || {}).sort((a, b) => b.length - a.length);
    document.documentElement.lang = locale === 'zh-Hans' ? 'zh-CN' : locale === 'zh-Hant' ? 'zh-TW' : locale;
    apply();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once: true });
  else start();
})();

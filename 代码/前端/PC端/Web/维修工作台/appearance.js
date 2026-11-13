// Created by Jobs. 主题只影响当前界面，不改变业务身份与请求。
(() => {
  const media = matchMedia('(prefers-color-scheme: dark)');
  const selector = document.querySelector('#appearanceTheme');
  let mode = 'system';
  try { mode = localStorage.getItem('repair-workbench-theme') || 'system'; } catch {}
  if (!['system', 'light', 'dark'].includes(mode)) mode = 'system';
  function apply() {
    const dark = mode === 'dark' || (mode === 'system' && media.matches);
    document.documentElement.dataset.theme = dark ? 'dark' : 'light';
    document.querySelector('meta[name="theme-color"]').content = dark ? '#101C18' : '#F3F6F4';
    selector.value = mode;
  }
  selector.addEventListener('change', () => {
    mode = selector.value;
    try { localStorage.setItem('repair-workbench-theme', mode); } catch {}
    apply();
  });
  media.addEventListener('change', apply);
  apply();
})();

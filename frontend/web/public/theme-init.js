// Runs before first paint (external file => compatible with a strict CSP, no inline script).
(function () {
  var theme = null;
  try { theme = localStorage.getItem('st-theme'); } catch (e) {}
  if (theme !== 'dark' && theme !== 'light') {
    theme = window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
  }
  document.documentElement.dataset.theme = theme;
  var meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute('content', theme === 'light' ? '#ebf5ff' : '#071329');
})();

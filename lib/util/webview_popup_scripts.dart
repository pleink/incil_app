/// JavaScript snippets injected into the huulo WebView to suppress
/// web-only popups (cookie banner + web push prompt) — issue #18.
///
/// The huulo app persists both choices in localStorage (Quasar format):
///   `@huulo/consent/cookie`               `__q_bool|1` = accepted
///   `@huulo/push/initialPermissionShown`  `__q_bool|1` = prompt handled
/// Seeding those keys before the SPA boots means the dialogs never mount.
/// Push stays "Nein" on the web side because notifications are delivered
/// natively via OneSignal, not via web push.
abstract final class WebViewPopupScripts {
  /// Injected on `onPageStarted`, before the huulo bundle has executed.
  /// Only seeds keys that are absent so a real user choice is never
  /// overwritten.
  static const String preseedConsent = '''
(function () {
  try {
    var seed = function (key, value) {
      if (localStorage.getItem(key) === null) localStorage.setItem(key, value);
    };
    seed('@huulo/consent/cookie', '__q_bool|1');
    seed('@huulo/push/initialPermissionShown', '__q_bool|1');
  } catch (e) {}
})();
''';

  /// Injected on `onPageFinished` as a safety net in case [preseedConsent]
  /// ran after the SPA already mounted the dialogs. Watches the DOM for up
  /// to 30s and dismisses them the way a user would: "Akzeptieren" on the
  /// cookie banner, "Nein" on the push prompt. The `q-item` needs a full
  /// pointer/mouse event sequence — a bare click() is ignored by Quasar.
  static const String dismissPopups = '''
(function () {
  if (window.__incilPopupDismisser) return;
  window.__incilPopupDismisser = true;
  var fire = function (el) {
    if (!el) return;
    var r = el.getBoundingClientRect();
    var opts = {
      bubbles: true, cancelable: true, composed: true, button: 0,
      clientX: r.x + r.width / 2, clientY: r.y + r.height / 2
    };
    el.dispatchEvent(new PointerEvent('pointerdown', opts));
    el.dispatchEvent(new MouseEvent('mousedown', opts));
    el.dispatchEvent(new PointerEvent('pointerup', opts));
    el.dispatchEvent(new MouseEvent('mouseup', opts));
    el.dispatchEvent(new MouseEvent('click', opts));
  };
  var findByText = function (root, selector, pattern) {
    var els = root.querySelectorAll(selector);
    for (var i = 0; i < els.length; i++) {
      if (pattern.test((els[i].innerText || '').trim())) return els[i];
    }
    return null;
  };
  var dismiss = function () {
    var cookie = document.querySelector('.q-card.cookie-consent');
    if (cookie) fire(findByText(cookie, 'button', /^akzeptieren\$/i));
    var push = document.querySelector('.q-card.initial-notification-permission');
    if (push) fire(findByText(push, '.q-item', /^nein\$/i));
  };
  var observer = new MutationObserver(dismiss);
  observer.observe(document.documentElement, { childList: true, subtree: true });
  setTimeout(function () { observer.disconnect(); }, 30000);
  dismiss();
})();
''';
}

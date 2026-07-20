import 'dart:convert';

import 'host_allowlist.dart';

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
  static const externalBrowserChannel = 'IncilExternalBrowser';

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

  /// Removes Huulo's Google login option inside the WebView. The Firebase
  /// redirect flow loses its browser session state in embedded auth contexts,
  /// so the native shell hides that option and leaves email/password auth.
  static const String removeGoogleLogin = '''
(function () {
  var normalize = function (text) {
    return (text || '').replace(/\\s+/g, ' ').trim();
  };

  var remove = function () {
    try {
      if (window.location.pathname !== '/login') return;

      var buttons = document.querySelectorAll('button, [role="button"], .q-btn');
      var googleButton = null;
      for (var i = 0; i < buttons.length; i++) {
        if (normalize(buttons[i].innerText).indexOf('Login mit Google') !== -1) {
          googleButton = buttons[i];
          break;
        }
      }

      var root = document;
      if (googleButton) {
        var container = googleButton.parentElement;
        for (var depth = 0; container && depth < 4; depth++) {
          var text = normalize(container.innerText).toLowerCase();
          if (text.indexOf('login mit google') !== -1 && text.indexOf('oder') !== -1) {
            root = container;
            break;
          }
          container = container.parentElement;
        }
      }

      var textEls = root.querySelectorAll('div, span, p');
      for (var j = 0; j < textEls.length; j++) {
        if (normalize(textEls[j].innerText).toLowerCase() === 'oder') {
          textEls[j].remove();
        }
      }

      if (googleButton) googleButton.remove();
    } catch (e) {}
  };

  window.__incilRemoveGoogleLogin = remove;
  if (window.__incilGoogleLoginRemover) {
    remove();
    return;
  }
  window.__incilGoogleLoginRemover = true;

  var observer = new MutationObserver(remove);
  observer.observe(document.documentElement, { childList: true, subtree: true });
  setTimeout(function () { observer.disconnect(); }, 30000);
  remove();
})();
''';

  /// Intercepts Huulo SPA clicks/routes that should leave the app. This
  /// complements the native navigation delegate: Vue router links can update
  /// history without producing a WebView navigation request.
  static String externalBrowserInterceptor(List<String> externalBrowserUrls) {
    final entries = externalBrowserUrls
        .map(normalizeExternalBrowserUrlEntry)
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
    return '''
(function () {
  window.__incilExternalBrowserUrls = ${jsonEncode(entries)};

  var normalizePath = function (path) {
    if (!path) return '/';
    return path.length > 1 && path.slice(-1) === '/' ? path.slice(0, -1) : path;
  };

  var matches = function (rawUrl) {
    try {
      var url = new URL(rawUrl, window.location.href);
      if (url.protocol !== 'http:' && url.protocol !== 'https:') return false;
      var entries = window.__incilExternalBrowserUrls || [];
      for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        if (!entry) continue;
        if (entry.charAt(0) === '/') {
          if (normalizePath(url.pathname) === normalizePath(entry)) return true;
          continue;
        }
        var configured = new URL(entry, window.location.href);
        if (url.protocol !== configured.protocol) continue;
        if (url.hostname.toLowerCase() !== configured.hostname.toLowerCase()) continue;
        if (normalizePath(url.pathname) !== normalizePath(configured.pathname)) continue;
        if (configured.search && url.search !== configured.search) continue;
        return true;
      }
    } catch (e) {}
    return false;
  };

  var post = function (rawUrl) {
    try {
      var url = new URL(rawUrl, window.location.href);
      window.$externalBrowserChannel.postMessage(url.href);
    } catch (e) {}
  };

  if (!window.__incilExternalBrowserClickHandler) {
    window.__incilExternalBrowserClickHandler = function (event) {
      var el = event.target;
      while (el && el !== document.documentElement) {
        var href = el.getAttribute && el.getAttribute('href');
        if (href && matches(href)) {
          event.preventDefault();
          event.stopPropagation();
          event.stopImmediatePropagation && event.stopImmediatePropagation();
          post(href);
          return false;
        }
        el = el.parentElement;
      }
    };
    document.addEventListener('click', window.__incilExternalBrowserClickHandler, true);
  }

  if (!window.__incilExternalBrowserHistoryPatched) {
    window.__incilExternalBrowserHistoryPatched = true;
    var patch = function (name) {
      var original = history[name];
      history[name] = function (state, title, url) {
        if (url && matches(url)) {
          post(url);
          return;
        }
        return original.apply(this, arguments);
      };
    };
    patch('pushState');
    patch('replaceState');
  }
})();
''';
  }

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

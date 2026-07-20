/// Returns `true` if the given URI's host matches one of [allowedHosts]
/// (exact match or subdomain), and the scheme is `http`/`https`.
///
/// Non-web schemes (`tel:`, `mailto:`, `intent:`, …) always return `false`
/// so the WebView never tries to load them — the caller should hand them
/// to the OS via `url_launcher` instead.
bool isHostAllowed(Uri uri, List<String> allowedHosts) {
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;
  final host = uri.host.toLowerCase();
  for (final raw in allowedHosts) {
    final allowed = raw.toLowerCase().trim();
    if (allowed.isEmpty) continue;
    if (host == allowed) return true;
    if (host.endsWith('.$allowed')) return true;
  }
  return false;
}

/// Returns `true` when [uri] matches one of the configured external-browser
/// URL entries. Absolute entries match scheme, host, path, and query when the
/// entry includes a query. Path-only entries such as `/signup` match the path
/// on any host so Firestore config can survive event-domain changes.
bool isExternalBrowserUrl(Uri uri, List<String> externalBrowserUrls) {
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;

  for (final raw in externalBrowserUrls) {
    final entry = normalizeExternalBrowserUrlEntry(raw);
    if (entry.isEmpty) continue;

    if (entry.startsWith('/')) {
      if (_pathsMatch(uri.path, entry)) return true;
      continue;
    }

    final configured = Uri.tryParse(entry);
    if (configured == null) continue;
    if (configured.scheme != 'http' && configured.scheme != 'https') {
      continue;
    }
    if (configured.host.isEmpty) continue;

    final sameOrigin =
        uri.scheme.toLowerCase() == configured.scheme.toLowerCase() &&
        uri.host.toLowerCase() == configured.host.toLowerCase();
    if (!sameOrigin) continue;
    if (!_pathsMatch(uri.path, configured.path)) continue;
    if (configured.hasQuery && uri.query != configured.query) continue;
    return true;
  }
  return false;
}

String normalizeExternalBrowserUrlEntry(String raw) {
  var entry = raw.trim();
  while (entry.length >= 2) {
    final first = entry[0];
    final last = entry[entry.length - 1];
    if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
      entry = entry.substring(1, entry.length - 1).trim();
    } else {
      break;
    }
  }
  return entry;
}

bool _pathsMatch(String actual, String configured) {
  final normalizedActual = _normalizePath(actual);
  final normalizedConfigured = _normalizePath(configured);
  return normalizedActual == normalizedConfigured;
}

String _normalizePath(String path) {
  if (path.isEmpty) return '/';
  if (path.length > 1 && path.endsWith('/')) {
    return path.substring(0, path.length - 1);
  }
  return path;
}

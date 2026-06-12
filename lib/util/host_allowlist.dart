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

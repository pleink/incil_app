void main() {
  throw StateError(
    'Use lib/main_dev.dart or lib/main_prod.dart as the entrypoint, e.g.\n'
    '  fvm flutter run --flavor dev -t lib/main_dev.dart\n'
    '  fvm flutter run --flavor prod -t lib/main_prod.dart',
  );
}

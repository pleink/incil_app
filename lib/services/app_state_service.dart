import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import '../models/app_state.dart';
import 'local_storage_service.dart';

class AppStateService {
  AppStateService({
    required FirebaseFirestore firestore,
    required LocalStorageService storage,
    AppState? fallback,
  }) : _firestore = firestore,
       _storage = storage,
       _hasFirestoreData = (storage.readCachedAppState()) != null,
       _subject = BehaviorSubject<AppState?>.seeded(
         storage.readCachedAppState() ?? fallback,
       );

  final FirebaseFirestore _firestore;
  final LocalStorageService _storage;
  final BehaviorSubject<AppState?> _subject;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  bool _hasFirestoreData;

  /// True once a Firestore snapshot has been successfully parsed, or true at
  /// construction if a cached AppState was loaded from local storage. False
  /// when the cubit is running purely on the `Flavor.defaultAppState` fallback.
  bool get hasRealData => _hasFirestoreData;

  /// Flat remote-control collection: one document per concern
  /// (webview, allowedHosts, emergency, forceUpdate, onboarding,
  /// oneSignalTags).
  static const _collectionPath = 'config';

  Stream<AppState?> get stream => _subject.stream;
  AppState? get current => _subject.valueOrNull;

  void start() {
    if (_sub != null) return;
    _sub = _firestore
        .collection(_collectionPath)
        .snapshots()
        .listen(
          _onSnapshot,
          onError: (Object e, StackTrace st) {
            developer.log(
              'Firestore stream error; cache will continue to serve callers.',
              name: 'AppStateService',
              error: e,
              stackTrace: st,
            );
            // Firestore SDK auto-reconnects when network returns; no manual retry needed.
          },
        );
  }

  Future<void> _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) async {
    if (snap.docs.isEmpty) return;
    final docs = {for (final doc in snap.docs) doc.id: doc.data()};
    try {
      final state = AppState.fromConfigDocs(docs);
      await _storage.writeCachedAppState(state);
      _hasFirestoreData = true;
      _subject.add(state);
    } catch (e, st) {
      developer.log(
        'Failed to parse AppState payload; keeping previous state.',
        name: 'AppStateService',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> retry() async {
    await _sub?.cancel();
    _sub = null;
    start();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _subject.close();
  }
}

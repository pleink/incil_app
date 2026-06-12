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
  }) : _firestore = firestore,
       _storage = storage,
       _subject = BehaviorSubject<AppState?>.seeded(
         storage.readCachedAppState(),
       );

  final FirebaseFirestore _firestore;
  final LocalStorageService _storage;
  final BehaviorSubject<AppState?> _subject;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  static const _docPath = 'apps/incil/config/app_state';

  Stream<AppState?> get stream => _subject.stream;
  AppState? get current => _subject.valueOrNull;

  void start() {
    if (_sub != null) return;
    _sub = _firestore
        .doc(_docPath)
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

  Future<void> _onSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) async {
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null) return;
    try {
      final state = AppState.fromJson(data);
      await _storage.writeCachedAppState(state);
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

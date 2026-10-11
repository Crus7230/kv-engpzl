import 'dart:async';
import 'dart:convert';

import '../domain/progress_models.dart';

export '../domain/progress_models.dart' show FutureSaveVersionException;

abstract interface class KeyValueSaveStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class MemoryKeyValueSaveStore implements KeyValueSaveStore {
  MemoryKeyValueSaveStore([Map<String, String> values = const {}])
    : values = {...values};
  final Map<String, String> values;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class SaveWriteException implements Exception {
  const SaveWriteException(this.message);
  final String message;
  @override
  String toString() => 'SaveWriteException: $message';
}

class CorruptSaveException implements Exception {
  const CorruptSaveException();
  @override
  String toString() =>
      'Both save slots are corrupt. Existing data has been preserved.';
}

/// Serializes all read/transform/commit operations within this repository.
/// The pointer is the commit marker: a newer uncommitted slot never wins over
/// a valid pointer. A failed write leaves the previously committed slot intact.
class ProgressRepository {
  ProgressRepository(this.store, {SaveEnvelopeV1 Function()? initialFactory})
    : _initialFactory = initialFactory ?? SaveEnvelopeV1.initial;

  static const slotAKey = 'kvm.renewal.save.v1.slot.a';
  static const slotBKey = 'kvm.renewal.save.v1.slot.b';
  static const pointerKey = 'kvm.renewal.save.v1.active';
  final KeyValueSaveStore store;
  final SaveEnvelopeV1 Function() _initialFactory;
  Future<void> _tail = Future<void>.value();
  SaveEnvelopeV1? _cached;
  String? _activeKey;

  Future<SaveEnvelopeV1> load() => _serialize(_load);

  Future<SaveEnvelopeV1> save(SaveEnvelopeV1 snapshot) => _serialize(() async {
    final current = await _load();
    if (snapshot.generation != current.generation) {
      throw StateError(
        'Stale save generation. Use update for concurrent changes.',
      );
    }
    return _commit(snapshot, current);
  });

  Future<SaveEnvelopeV1> update(
    SaveEnvelopeV1 Function(SaveEnvelopeV1 current) transform,
  ) => _serialize(() async {
    final current = await _load();
    final changed = transform(current);
    if (identical(current, changed)) return current;
    if (changed.generation != current.generation) {
      throw StateError('Only the repository may increment save generation.');
    }
    return _commit(changed, current);
  });

  Future<T> _serialize<T>(Future<T> Function() action) {
    final completion = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completion.complete(await action());
      } catch (error, stack) {
        completion.completeError(error, stack);
      }
    });
    return completion.future;
  }

  Future<SaveEnvelopeV1> _load() async {
    if (_cached != null) return _cached!;
    final pointer = await store.read(pointerKey);
    final rawA = await store.read(slotAKey);
    final rawB = await store.read(slotBKey);
    final a = _decode(rawA);
    final b = _decode(rawB);
    final preferred = pointer == 'a'
        ? a
        : pointer == 'b'
        ? b
        : null;
    if (preferred != null) {
      _cached = preferred;
      _activeKey = pointer == 'a' ? slotAKey : slotBKey;
    } else if (a != null || b != null) {
      // Recovery from a corrupt/missing pointer or corrupt committed slot.
      final chooseA = b == null || (a != null && a.generation >= b.generation);
      _cached = chooseA ? a : b;
      _activeKey = chooseA ? slotAKey : slotBKey;
    } else if (rawA == null && rawB == null && pointer == null) {
      _cached = _initialFactory();
      _activeKey = null;
    } else {
      throw const CorruptSaveException();
    }
    return _cached!;
  }

  SaveEnvelopeV1? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return SaveEnvelopeV1.fromJson(json);
    } on FutureSaveVersionException {
      // Do not silently fall back and later overwrite data from a newer app.
      rethrow;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<SaveEnvelopeV1> _commit(
    SaveEnvelopeV1 snapshot,
    SaveEnvelopeV1 previous,
  ) async {
    snapshot.validate();
    final committed = snapshot.copyWith(generation: previous.generation + 1);
    final encoded = jsonEncode(committed.toJson());
    try {
      // Establish a recoverable generation-zero checkpoint before the first
      // transaction. A failed first pointer write must not recover an orphan
      // generation-one reward as though it had been committed.
      if (_activeKey == null) {
        final baseline = jsonEncode(previous.toJson());
        await store.write(slotAKey, baseline);
        if (await store.read(slotAKey) != baseline) {
          throw const SaveWriteException('Initial checkpoint readback failed.');
        }
        await store.write(pointerKey, 'a');
        if (await store.read(pointerKey) != 'a') {
          throw const SaveWriteException('Initial checkpoint pointer failed.');
        }
        _activeKey = slotAKey;
      }
      final target = _activeKey == slotAKey ? slotBKey : slotAKey;
      await store.write(target, encoded);
      final readBack = await store.read(target);
      if (readBack != encoded ||
          _decode(readBack)?.generation != committed.generation) {
        throw const SaveWriteException('Inactive slot readback failed.');
      }
      final pointer = target == slotAKey ? 'a' : 'b';
      await store.write(pointerKey, pointer);
      if (await store.read(pointerKey) != pointer) {
        throw const SaveWriteException('Commit pointer readback failed.');
      }
      _activeKey = target;
      _cached = committed;
      return committed;
    } catch (_) {
      // Re-read the marker on the next operation. The pointer write may have
      // succeeded even when its acknowledgement/readback failed.
      _cached = null;
      _activeKey = null;
      rethrow;
    }
  }
}

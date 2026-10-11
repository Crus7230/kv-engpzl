import 'discovery_models.dart';

abstract interface class DiscoveryPieceSource {
  DiscoveryPiece nextPiece(DiscoveryPosition position);
}

class SeededGemPieceSource implements DiscoveryPieceSource {
  SeededGemPieceSource({
    required int seed,
    this.idPrefix = 'refill',
    List<String> gemKeys = const ['coral', 'gold', 'mint', 'sky', 'violet'],
  }) : _state = seed & 0xffffffff,
       _gemKeys = List.unmodifiable(gemKeys) {
    if (_gemKeys.length < 3 || _gemKeys.any((key) => key.isEmpty)) {
      throw ArgumentError.value(
        gemKeys,
        'gemKeys',
        'Provide at least three non-empty gem keys.',
      );
    }
  }

  final String idPrefix;
  final List<String> _gemKeys;
  int _state;
  int _sequence = 0;

  @override
  DiscoveryPiece nextPiece(DiscoveryPosition position) {
    _state = (1664525 * _state + 1013904223) % 0x100000000;
    final gemKey = _gemKeys[_state % _gemKeys.length];
    final id = '$idPrefix-${_sequence++}';
    return DiscoveryPiece.gem(id: id, gemKey: gemKey);
  }
}

class QueuedPieceSource implements DiscoveryPieceSource {
  QueuedPieceSource({required Iterable<DiscoveryPiece> pieces, this.fallback})
    : _pieces = List.unmodifiable(pieces);

  final List<DiscoveryPiece> _pieces;
  final DiscoveryPieceSource? fallback;
  int _index = 0;

  int get remaining => _pieces.length - _index;

  @override
  DiscoveryPiece nextPiece(DiscoveryPosition position) {
    if (_index < _pieces.length) {
      return _pieces[_index++];
    }
    final fallback = this.fallback;
    if (fallback == null) {
      throw StateError('The queued refill source is empty.');
    }
    return fallback.nextPiece(position);
  }
}

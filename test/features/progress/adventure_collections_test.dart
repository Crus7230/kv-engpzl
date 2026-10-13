import 'package:flutter_test/flutter_test.dart';

import '../../../tool/verify_adventure_collections.dart' as verifier;

void main() {
  test(
    'adventure collections preserve saves, learning evidence and gates',
    verifier.main,
  );
}

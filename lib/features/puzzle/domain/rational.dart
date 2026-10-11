class Rational implements Comparable<Rational> {
  factory Rational(int numerator, [int denominator = 1]) {
    if (denominator == 0) {
      throw ArgumentError.value(
        denominator,
        'denominator',
        'Must not be zero.',
      );
    }

    final sign = denominator < 0 ? -1 : 1;
    final divisor = _greatestCommonDivisor(numerator.abs(), denominator.abs());
    return Rational._(
      sign * numerator ~/ divisor,
      denominator.abs() ~/ divisor,
    );
  }

  const Rational._(this.numerator, this.denominator);

  final int numerator;
  final int denominator;

  bool get isZero => numerator == 0;

  Rational operator +(Rational other) => Rational(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );

  Rational operator -(Rational other) => Rational(
    numerator * other.denominator - other.numerator * denominator,
    denominator * other.denominator,
  );

  Rational operator *(Rational other) =>
      Rational(numerator * other.numerator, denominator * other.denominator);

  Rational operator /(Rational other) {
    if (other.isZero) {
      throw UnsupportedError('Division by zero.');
    }
    return Rational(
      numerator * other.denominator,
      denominator * other.numerator,
    );
  }

  @override
  int compareTo(Rational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  @override
  bool operator ==(Object other) =>
      other is Rational &&
      numerator == other.numerator &&
      denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() =>
      denominator == 1 ? '$numerator' : '$numerator/$denominator';
}

int _greatestCommonDivisor(int left, int right) {
  var a = left;
  var b = right;
  while (b != 0) {
    final remainder = a % b;
    a = b;
    b = remainder;
  }
  return a == 0 ? 1 : a;
}

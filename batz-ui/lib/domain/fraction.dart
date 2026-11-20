/// An exact rational number, always in lowest terms with a positive
/// denominator. No floating point is used in calculations (design rule 6 of
/// phase 1).
class Fraction implements Comparable<Fraction> {
  factory Fraction(int numerator, [int denominator = 1]) =>
      Fraction._normalised(BigInt.from(numerator), BigInt.from(denominator));

  Fraction._(this.numerator, this.denominator);

  factory Fraction._normalised(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.zero) throw ArgumentError.value(denominator, 'denominator', 'zero');
    if (denominator.isNegative) {
      numerator = -numerator;
      denominator = -denominator;
    }
    final divisor = numerator.gcd(denominator);
    return divisor == BigInt.one
        ? Fraction._(numerator, denominator)
        : Fraction._(numerator ~/ divisor, denominator ~/ divisor);
  }

  static final zero = Fraction(0);
  static final one = Fraction(1);

  final BigInt numerator;
  final BigInt denominator;

  Fraction operator +(Fraction other) => Fraction._normalised(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );

  Fraction operator -(Fraction other) => this + -other;

  Fraction operator -() => Fraction._(-numerator, denominator);

  Fraction get abs => numerator.isNegative ? -this : this;

  /// 1 divided by this fraction.
  Fraction get reciprocal => Fraction._normalised(denominator, numerator);

  Fraction operator *(Fraction other) =>
      Fraction._normalised(numerator * other.numerator, denominator * other.denominator);

  bool get isInteger => denominator == BigInt.one;

  @override
  int compareTo(Fraction other) => (numerator * other.denominator).compareTo(other.numerator * denominator);

  @override
  bool operator ==(Object other) =>
      other is Fraction && numerator == other.numerator && denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => isInteger ? '$numerator' : '$numerator/$denominator';
}

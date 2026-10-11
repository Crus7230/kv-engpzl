enum EquationTokenKind { number, operator, leftParenthesis, rightParenthesis }

class EquationToken {
  const EquationToken({
    required this.id,
    required this.label,
    required this.kind,
  });

  final String id;
  final String label;
  final EquationTokenKind kind;

  bool get isOperator => kind == EquationTokenKind.operator;
  bool get isParenthesis =>
      kind == EquationTokenKind.leftParenthesis ||
      kind == EquationTokenKind.rightParenthesis;

  @override
  bool operator ==(Object other) => other is EquationToken && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

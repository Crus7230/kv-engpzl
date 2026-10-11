import 'equation_token.dart';
import 'rational.dart';

enum EquationErrorCode {
  emptyExpression,
  expectedOperand,
  expectedOperator,
  unbalancedParentheses,
  unsupportedOperator,
  invalidNumber,
  divisionByZero,
  malformedExpression,
}

class EquationEvaluation {
  const EquationEvaluation.success(this.expression, this.value)
    : error = null,
      tokenId = null;

  const EquationEvaluation.failure(this.error, {this.tokenId})
    : expression = null,
      value = null;

  final ExpressionNode? expression;
  final Rational? value;
  final EquationErrorCode? error;
  final String? tokenId;

  bool get isSuccess => value != null && error == null;
}

sealed class ExpressionNode {
  const ExpressionNode();

  ExpressionSignature get signature;

  Rational evaluate();
}

final class ExpressionSignature {
  const ExpressionSignature._(this._canonical);

  factory ExpressionSignature.number(String tokenId) {
    return ExpressionSignature._('N${_segment(tokenId)}');
  }

  factory ExpressionSignature.binary({
    required String operatorLabel,
    required ExpressionSignature left,
    required ExpressionSignature right,
  }) {
    var leftValue = left._canonical;
    var rightValue = right._canonical;
    if (_commutativeOperators.contains(operatorLabel) &&
        leftValue.compareTo(rightValue) > 0) {
      final temporary = leftValue;
      leftValue = rightValue;
      rightValue = temporary;
    }
    return ExpressionSignature._(
      'B${_segment(operatorLabel)}'
      '${_segment(leftValue)}'
      '${_segment(rightValue)}',
    );
  }

  static const Set<String> _commutativeOperators = {'+', '×'};

  final String _canonical;

  static String _segment(String value) => '${value.length}:$value';

  @override
  bool operator ==(Object other) =>
      other is ExpressionSignature && other._canonical == _canonical;

  @override
  int get hashCode => _canonical.hashCode;

  @override
  String toString() => _canonical;
}

final class NumberExpression extends ExpressionNode {
  const NumberExpression({required this.token, required this.value});

  final EquationToken token;
  final Rational value;

  @override
  ExpressionSignature get signature => ExpressionSignature.number(token.id);

  @override
  Rational evaluate() => value;
}

final class BinaryExpression extends ExpressionNode {
  const BinaryExpression({
    required this.operatorToken,
    required this.left,
    required this.right,
  });

  final EquationToken operatorToken;
  final ExpressionNode left;
  final ExpressionNode right;

  @override
  ExpressionSignature get signature => ExpressionSignature.binary(
    operatorLabel: operatorToken.label,
    left: left.signature,
    right: right.signature,
  );

  @override
  Rational evaluate() {
    final leftValue = left.evaluate();
    final rightValue = right.evaluate();
    return switch (operatorToken.label) {
      '+' => leftValue + rightValue,
      '-' => leftValue - rightValue,
      '×' => leftValue * rightValue,
      '÷' when rightValue.isZero => throw _EquationDivisionByZero(
        operatorToken.id,
      ),
      '÷' => leftValue / rightValue,
      _ => throw UnsupportedError(
        'Unsupported operator: ${operatorToken.label}',
      ),
    };
  }
}

final class _EquationDivisionByZero implements Exception {
  const _EquationDivisionByZero(this.tokenId);

  final String tokenId;
}

class EquationEngine {
  const EquationEngine();

  static const Map<String, int> _precedence = {'+': 1, '-': 1, '×': 2, '÷': 2};

  EquationEvaluation evaluate(List<EquationToken> expression) {
    if (expression.isEmpty) {
      return const EquationEvaluation.failure(
        EquationErrorCode.emptyExpression,
      );
    }

    final postfix = <EquationToken>[];
    final operators = <EquationToken>[];
    var expectsOperand = true;

    for (final token in expression) {
      switch (token.kind) {
        case EquationTokenKind.number:
          if (!expectsOperand) {
            return EquationEvaluation.failure(
              EquationErrorCode.expectedOperator,
              tokenId: token.id,
            );
          }
          if (int.tryParse(token.label) == null) {
            return EquationEvaluation.failure(
              EquationErrorCode.invalidNumber,
              tokenId: token.id,
            );
          }
          postfix.add(token);
          expectsOperand = false;
        case EquationTokenKind.leftParenthesis:
          if (!expectsOperand) {
            return EquationEvaluation.failure(
              EquationErrorCode.expectedOperator,
              tokenId: token.id,
            );
          }
          operators.add(token);
        case EquationTokenKind.rightParenthesis:
          if (expectsOperand) {
            return EquationEvaluation.failure(
              EquationErrorCode.expectedOperand,
              tokenId: token.id,
            );
          }
          final openingIndex = operators.lastIndexWhere(
            (item) => item.kind == EquationTokenKind.leftParenthesis,
          );
          if (openingIndex == -1) {
            return EquationEvaluation.failure(
              EquationErrorCode.unbalancedParentheses,
              tokenId: token.id,
            );
          }
          while (operators.length - 1 > openingIndex) {
            postfix.add(operators.removeLast());
          }
          operators.removeLast();
          expectsOperand = false;
        case EquationTokenKind.operator:
          if (expectsOperand) {
            return EquationEvaluation.failure(
              EquationErrorCode.expectedOperand,
              tokenId: token.id,
            );
          }
          final tokenPrecedence = _precedence[token.label];
          if (tokenPrecedence == null) {
            return EquationEvaluation.failure(
              EquationErrorCode.unsupportedOperator,
              tokenId: token.id,
            );
          }
          while (operators.isNotEmpty &&
              operators.last.isOperator &&
              (_precedence[operators.last.label] ?? -1) >= tokenPrecedence) {
            postfix.add(operators.removeLast());
          }
          operators.add(token);
          expectsOperand = true;
      }
    }

    if (expectsOperand) {
      return EquationEvaluation.failure(
        EquationErrorCode.expectedOperand,
        tokenId: expression.last.id,
      );
    }

    while (operators.isNotEmpty) {
      final token = operators.removeLast();
      if (token.isParenthesis) {
        return EquationEvaluation.failure(
          EquationErrorCode.unbalancedParentheses,
          tokenId: token.id,
        );
      }
      postfix.add(token);
    }

    final nodes = <ExpressionNode>[];
    for (final token in postfix) {
      if (token.kind == EquationTokenKind.number) {
        final value = int.tryParse(token.label);
        if (value == null) {
          return EquationEvaluation.failure(
            EquationErrorCode.invalidNumber,
            tokenId: token.id,
          );
        }
        nodes.add(NumberExpression(token: token, value: Rational(value)));
        continue;
      }

      if (nodes.length < 2) {
        return EquationEvaluation.failure(
          EquationErrorCode.malformedExpression,
          tokenId: token.id,
        );
      }

      final right = nodes.removeLast();
      final left = nodes.removeLast();
      if (!_precedence.containsKey(token.label)) {
        return EquationEvaluation.failure(
          EquationErrorCode.unsupportedOperator,
          tokenId: token.id,
        );
      }
      nodes.add(
        BinaryExpression(operatorToken: token, left: left, right: right),
      );
    }

    if (nodes.length != 1) {
      return const EquationEvaluation.failure(
        EquationErrorCode.malformedExpression,
      );
    }

    final root = nodes.single;
    try {
      return EquationEvaluation.success(root, root.evaluate());
    } on _EquationDivisionByZero catch (error) {
      return EquationEvaluation.failure(
        EquationErrorCode.divisionByZero,
        tokenId: error.tokenId,
      );
    }
  }
}

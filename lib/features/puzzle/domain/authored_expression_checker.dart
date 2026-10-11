import 'equation_engine.dart';
import 'equation_token.dart';
import 'rational.dart';

class AuthoredExpressionCheck {
  const AuthoredExpressionCheck._({
    required this.isValid,
    this.value,
    this.error,
  });

  const AuthoredExpressionCheck.valid(Rational value)
    : this._(isValid: true, value: value);

  const AuthoredExpressionCheck.invalid(String error)
    : this._(isValid: false, error: error);

  final bool isValid;
  final Rational? value;
  final String? error;
}

/// Checks small integer expressions embedded in authored learning content.
///
/// This deliberately accepts only the same four operators and parentheses as
/// [EquationEngine]. Display-only units and prose stay outside the expression.
class AuthoredExpressionChecker {
  const AuthoredExpressionChecker({this.engine = const EquationEngine()});

  final EquationEngine engine;

  AuthoredExpressionCheck evaluate(String source) {
    final tokens = <EquationToken>[];
    var cursor = 0;
    var tokenIndex = 0;
    while (cursor < source.length) {
      final character = source[cursor];
      if (character.trim().isEmpty) {
        cursor += 1;
        continue;
      }
      if (_isDigit(character)) {
        final start = cursor;
        while (cursor < source.length && _isDigit(source[cursor])) {
          cursor += 1;
        }
        tokens.add(
          EquationToken(
            id: 'authored-$tokenIndex',
            label: source.substring(start, cursor),
            kind: EquationTokenKind.number,
          ),
        );
        tokenIndex += 1;
        continue;
      }
      final normalizedOperator = switch (character) {
        '*' => '×',
        '/' => '÷',
        '+' || '-' || '×' || '÷' => character,
        _ => null,
      };
      if (normalizedOperator != null) {
        tokens.add(
          EquationToken(
            id: 'authored-$tokenIndex',
            label: normalizedOperator,
            kind: EquationTokenKind.operator,
          ),
        );
      } else if (character == '(' || character == ')') {
        tokens.add(
          EquationToken(
            id: 'authored-$tokenIndex',
            label: character,
            kind: character == '('
                ? EquationTokenKind.leftParenthesis
                : EquationTokenKind.rightParenthesis,
          ),
        );
      } else {
        return AuthoredExpressionCheck.invalid(
          'Unsupported character "$character".',
        );
      }
      tokenIndex += 1;
      cursor += 1;
    }

    final evaluation = engine.evaluate(tokens);
    if (!evaluation.isSuccess) {
      return AuthoredExpressionCheck.invalid(
        'Expression error: ${evaluation.error?.name ?? 'unknown'}.',
      );
    }
    return AuthoredExpressionCheck.valid(evaluation.value!);
  }

  AuthoredExpressionCheck evaluateEquation(String source) {
    final parts = source.split('=');
    if (parts.length != 2) {
      return const AuthoredExpressionCheck.invalid(
        'A worked step must contain one equals sign.',
      );
    }
    final left = evaluate(parts.first);
    final right = evaluate(parts.last);
    if (!left.isValid || !right.isValid) {
      return AuthoredExpressionCheck.invalid(
        left.error ?? right.error ?? 'Invalid equation.',
      );
    }
    if (left.value != right.value) {
      return const AuthoredExpressionCheck.invalid(
        'Both sides of a worked step must have the same value.',
      );
    }
    return AuthoredExpressionCheck.valid(right.value!);
  }

  bool _isDigit(String character) {
    final codeUnit = character.codeUnitAt(0);
    return codeUnit >= 48 && codeUnit <= 57;
  }
}

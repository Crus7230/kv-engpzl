import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<void> showNoHeartsDialogAndGoHome(BuildContext context) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return AlertDialog(
        title: const Text('하트가 부족해요'),
        content: const Text('하트가 모두 소진되어 홈으로 이동합니다. 회복 후 다시 도전해 주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      );
    },
  );
  if (!context.mounted) return;
  context.go('/home');
}


import 'dart:math';

import 'package:flutter/material.dart';

import '../managers/character_manager.dart';

class CompactCharacterCheerCard extends StatefulWidget {
  const CompactCharacterCheerCard({
    super.key,
    required this.character,
    this.trailing,
    this.cheerMessages,
  });

  final CharacterProfile character;
  final Widget? trailing;
  final List<String>? cheerMessages;

  @override
  State<CompactCharacterCheerCard> createState() => _CompactCharacterCheerCardState();
}

class _CompactCharacterCheerCardState extends State<CompactCharacterCheerCard> {
  static const List<String> _defaultCheers = [
    '좋아요, 지금 리듬 그대로 가요!',
    '한 글자씩 차분히 보면 정답이 보여요.',
    '실수해도 괜찮아요. 다음 선택이 더 중요해요.',
    '지금 판단 아주 좋아요. 그대로 밀어봐요!',
    '막히면 숨 한번 쉬고 다시 보면 풀려요.',
    '집중력 최고예요. 이번 판 충분히 가능해요.',
    '작은 단서 하나가 큰 힌트가 될 거예요.',
    '좋은 흐름이에요. 페이스 유지해요.',
    '정답이 가까워요. 끝까지 침착하게!',
    '멋져요, 지금처럼만 하면 됩니다!',
  ];

  final Random _random = Random();
  late List<String> _messages;
  late String _message;

  @override
  void initState() {
    super.initState();
    _messages = _resolveMessages();
    _message = _messages[_random.nextInt(_messages.length)];
  }

  @override
  void didUpdateWidget(covariant CompactCharacterCheerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cheerMessages != widget.cheerMessages) {
      _messages = _resolveMessages();
      if (!_messages.contains(_message)) {
        _message = _messages[_random.nextInt(_messages.length)];
      }
    }
  }

  List<String> _resolveMessages() {
    final fromWidget = widget.cheerMessages?.where((msg) => msg.trim().isNotEmpty).toList() ?? const <String>[];
    return fromWidget.isEmpty ? _defaultCheers : fromWidget;
  }

  void _rotateMessage() {
    if (_messages.isEmpty) return;
    if (_messages.length == 1) return;
    String next = _message;
    while (next == _message) {
      next = _messages[_random.nextInt(_messages.length)];
    }
    setState(() => _message = next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _rotateMessage,
            child: CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage(widget.character.imagePath),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _rotateMessage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.character.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Text(
                      _message,
                      key: ValueKey(_message),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: 8),
            widget.trailing!,
          ],
        ],
      ),
    );
  }
}


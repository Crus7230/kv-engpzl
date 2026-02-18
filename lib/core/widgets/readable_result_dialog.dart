import 'package:flutter/material.dart';

class ResultLine {
  const ResultLine({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;
}

class ReadableResultDialog extends StatelessWidget {
  const ReadableResultDialog({
    super.key,
    required this.title,
    required this.success,
    required this.lines,
    required this.actions,
    this.headline,
  });

  final String title;
  final bool success;
  final String? headline;
  final List<ResultLine> lines;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final accent = success ? const Color(0xFF2B8A3E) : const Color(0xFFC92A2A);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Icon(success ? Icons.verified_rounded : Icons.warning_amber_rounded, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (headline != null && headline!.trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    headline!,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: line.accent ? const Color(0xFFE7F5FF) : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: line.accent ? const Color(0xFF74C0FC) : const Color(0xFFE9ECEF),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6C757D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          line.value,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: actions,
    );
  }
}


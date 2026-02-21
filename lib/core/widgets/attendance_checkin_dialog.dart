import 'package:flutter/material.dart';

class AttendanceCheckinDialog extends StatefulWidget {
  const AttendanceCheckinDialog({
    super.key,
    required this.streak,
    required this.starsGained,
    required this.today,
    required this.attendanceHistory,
    this.animateTodayStamp = true,
  });

  final int streak;
  final int starsGained;
  final DateTime today;
  final List<String> attendanceHistory;
  final bool animateTodayStamp;

  @override
  State<AttendanceCheckinDialog> createState() => _AttendanceCheckinDialogState();
}

class _AttendanceCheckinDialogState extends State<AttendanceCheckinDialog> {
  static const List<String> _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
  bool _showTodayStamp = false;

  @override
  void initState() {
    super.initState();
    if (!widget.animateTodayStamp) {
      _showTodayStamp = true;
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() => _showTodayStamp = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime(widget.today.year, widget.today.month, widget.today.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekDays = List.generate(7, (index) => weekStart.add(Duration(days: index)));
    final attendanceSet = widget.attendanceHistory.toSet();
    final weeklyCount = weekDays.where((day) => attendanceSet.contains(_dayKey(day))).length;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8E1), Color(0xFFFFF1F2)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFE066),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF9C6F00)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('오늘의 출석 체크', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      Text(
                        '${_weekdayLabels[today.weekday - 1]}요일 출석 완료',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF495057)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE8CC)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '연속 출석 ${widget.streak}일',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3BF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+${widget.starsGained}★',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFB08900)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '이번 주 출석부',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF495057)),
            ),
            const SizedBox(height: 8),
            Row(
              children: weekDays.map((day) {
                final attended = attendanceSet.contains(_dayKey(day));
                final isToday = _sameDay(today, day);
                final canShowStamp = !isToday || _showTodayStamp;
                return Expanded(
                  child: Column(
                    children: [
                      Text(_weekdayLabels[day.weekday - 1], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Container(
                        width: 38,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: attended ? const Color(0xFFFF6B6B) : const Color(0xFFDEE2E6)),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: 3,
                              child: Text(
                                '${day.day}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF868E96)),
                              ),
                            ),
                            if (attended && canShowStamp)
                              AnimatedScale(
                                scale: isToday ? (_showTodayStamp ? 1 : 0.2) : 1,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutBack,
                                child: Transform.rotate(
                                  angle: -0.2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE3E3),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: const Color(0xFFFF6B6B), width: 1.2),
                                    ),
                                    child: const Text(
                                      '출석',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFC92A2A),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 10),
            Text(
              '이번 주 $weeklyCount회 출석',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF495057)),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dayKey(DateTime day) {
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return '${day.year}-$mm-$dd';
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}


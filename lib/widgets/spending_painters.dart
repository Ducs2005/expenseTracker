import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/expense.dart';

const chartColors = [
  Color(0xFF235D4B),
  Color(0xFFE6A65D),
  Color(0xFF8BA89B),
  Color(0xFFB88E8C),
  Color(0xFF8096B0),
];

class CategoryDonutPainter extends CustomPainter {
  const CategoryDonutPainter({
    required this.values,
    required this.progress,
    required this.selectedIndex,
  });

  final List<double> values;
  final double progress;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCenter(center: center, width: 116, height: 116);
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = const Color(0xFFE6ECE8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 15,
      );
      return;
    }

    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2 * progress;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = chartColors[i % chartColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = selectedIndex == i ? 19 : 15
          ..strokeCap = StrokeCap.round,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CategoryDonutPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.progress != progress ||
      oldDelegate.selectedIndex != selectedIndex;
}

class WeekBarsPainter extends CustomPainter {
  const WeekBarsPainter({
    required this.expenses,
    required this.progress,
    required this.selectedIndex,
  });

  final List<Expense> expenses;
  final double progress;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final today = DateTime.now();
    final monday = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    final values = List<double>.generate(7, (index) {
      final day = monday.add(Duration(days: index));
      return expenses
          .where((expense) =>
              expense.date.year == day.year &&
              expense.date.month == day.month &&
              expense.date.day == day.day)
          .fold<double>(0, (sum, expense) => sum + expense.amount);
    });
    final maxValue = values.fold<double>(
        0, (largest, value) => math.max(largest, value).toDouble());
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final columnWidth = size.width / 7;

    for (var i = 0; i < 7; i++) {
      final centerX = columnWidth * (i + 0.5);
      final rawHeight = maxValue == 0 ? 4.0 : values[i] / maxValue * 43;
      final barHeight = rawHeight.clamp(4.0, 43.0).toDouble() * progress;
      final color = i == selectedIndex
          ? const Color(0xFF163F34)
          : i == today.weekday - 1
              ? chartColors.first
              : const Color(0xFFDCE5E0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(centerX - 6, 51 - barHeight, 12, barHeight),
          const Radius.circular(6),
        ),
        Paint()..color = color,
      );

      final label = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: Color(0xFF84908B), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(centerX - label.width / 2, 61));
    }
  }

  @override
  bool shouldRepaint(covariant WeekBarsPainter oldDelegate) =>
      oldDelegate.expenses != expenses ||
      oldDelegate.progress != progress ||
      oldDelegate.selectedIndex != selectedIndex;
}

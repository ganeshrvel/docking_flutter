import 'dart:math' as math;

import 'package:docking/docking.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

@internal
class DropFeedbackWidget extends StatelessWidget {
  final Widget child;
  final DropPosition? dropPosition;
  final Color accentColor;

  const DropFeedbackWidget({
    Key? key,
    this.dropPosition,
    required this.child,
    required this.accentColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        foregroundPainter: _CustomPainter(dropPosition, accentColor),
        child: child);
  }
}

class _CustomPainter extends CustomPainter {
  _CustomPainter(this.dropPosition, this.accentColor);

  final DropPosition? dropPosition;
  final Color accentColor;

  static const _dash = 8.0;
  static const _gap = 4.0;
  static const _strokeW = 2.0;
  static const _radius = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (dropPosition == null) return;

    late Rect rect;
    if (dropPosition == DropPosition.top) {
      rect = Rect.fromLTWH(0, 0, size.width, size.height / 2);
    } else if (dropPosition == DropPosition.bottom) {
      rect = Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2);
    } else if (dropPosition == DropPosition.left) {
      rect = Rect.fromLTWH(0, 0, size.width / 2, size.height);
    } else if (dropPosition == DropPosition.right) {
      rect = Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);
    } else {
      throw StateError('Unexpected drop position: $dropPosition');
    }

    final rRect = RRect.fromRectAndRadius(
        rect.deflate(_strokeW / 2), const Radius.circular(_radius));

    // fill
    canvas.drawRRect(
        rRect,
        Paint()
          ..color = accentColor.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill);

    // dashed border
    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeW;

    _drawDashedRRect(canvas, rRect, borderPaint);
  }

  void _drawDashedRRect(Canvas canvas, RRect rRect, Paint paint) {
    final path = Path()..addRRect(rRect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? _dash : _gap;
        final end = math.min(distance + len, metric.length);
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, end), paint);
        }
        distance = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CustomPainter oldDelegate) =>
      dropPosition != oldDelegate.dropPosition ||
      accentColor != oldDelegate.accentColor;
}

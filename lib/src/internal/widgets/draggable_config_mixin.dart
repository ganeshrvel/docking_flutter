import 'package:docking/src/drag_over_position.dart';
import 'package:docking/src/layout/docking_layout.dart';
import 'package:fluent_ui/fluent_ui.dart' show FluentTheme;
import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import 'package:tabbed_view/tabbed_view.dart';

@internal
mixin DraggableConfigMixin {
  DraggableConfig buildDraggableConfig(
      {required DragOverPosition dockingDrag,
      required TabData tabData,
      required BuildContext context}) {
    DockingItem item = tabData.value;
    String name = item.name != null ? item.name! : '';
    final Color accent = FluentTheme.of(context)
        .accentColor
        .defaultBrushFor(FluentTheme.of(context).brightness);
    return DraggableConfig(
        feedback: buildFeedback(name, accent),
        dragAnchorStrategy: (Draggable<Object> draggable, BuildContext context,
                Offset position) =>
            Offset(20, 20),
        onDragStarted: () {
          dockingDrag.enable = true;
        },
        onDragCompleted: () {
          dockingDrag.enable = false;
        },
        onDraggableCanceled: (velocity, offset) {
          dockingDrag.enable = false;
        },
        onDragEnd: (details) {
          dockingDrag.enable = false;
        });
  }

  Widget buildFeedback(String name, Color accent) {
    return CustomPaint(
      painter: _DashedBorderPainter(accent),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 30,
          maxWidth: 150,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.folder,
              size: 15,
              color: accent,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: accent,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const radius = Radius.circular(8);
    final rRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height), radius);
    final path = Path()..addRRect(rRect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? 6.0 : 3.0;
        final end = (distance + len).clamp(0.0, metric.length);
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, end), paint);
        }
        distance = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      accent != oldDelegate.accent;
}

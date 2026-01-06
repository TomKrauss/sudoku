import 'package:flutter/material.dart';

class _GridPaperPainter extends CustomPainter {
  const _GridPaperPainter({
    required this.color,
    required this.interval,
    required this.divisions,
    required this.subdivisions,
  });

  final Color color;
  final double interval;
  final int divisions;
  final int subdivisions;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()..color = color;
    linePaint.strokeCap = StrokeCap.round;
    final double allDivisions = (divisions * subdivisions).toDouble();
    for (double x = 0.0; x <= size.width; x += interval / allDivisions) {
      linePaint.strokeWidth =
      (x % interval == 0.0)
          ? 2
          : (x % (interval / subdivisions) == 0.0)
          ? 1.5
          : 0.5;
      canvas.drawLine(Offset(x, 0.0), Offset(x, size.height), linePaint);
    }
    for (double y = 0.0; y <= size.height; y += interval / allDivisions) {
      linePaint.strokeWidth =
      (y % interval == 0.0)
          ? 2
          : (y % (interval / subdivisions) == 0.0)
          ? 1.5
          : 0.5;
      canvas.drawLine(Offset(0.0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(_GridPaperPainter oldPainter) {
    return oldPainter.color != color ||
        oldPainter.interval != interval ||
        oldPainter.divisions != divisions ||
        oldPainter.subdivisions != subdivisions;
  }

  @override
  bool hitTest(Offset position) => false;
}

/// A widget that draws a rectilinear grid of lines one pixel wide.
///
/// The grid is drawn over the [child] widget.
class CustomGridPaper extends StatelessWidget {
  /// Creates a widget that draws a rectilinear grid of 1-pixel-wide lines.
  const CustomGridPaper({
    super.key,
    this.color = const Color(0x7FC3E8F3),
    this.interval = 100.0,
    this.divisions = 2,
    this.subdivisions = 5,
    this.child,
  });

  /// The color to draw the lines in the grid.
  ///
  /// Defaults to a light blue commonly seen on traditional grid paper.
  final Color color;

  /// The distance between the primary lines in the grid, in logical pixels.
  ///
  /// Each primary line is one logical pixel wide.
  final double interval;

  /// The number of major divisions within each primary grid cell.
  ///
  /// This is the number of major divisions per [interval], including the
  /// primary grid's line.
  ///
  /// The lines after the first are half a logical pixel wide.
  ///
  /// If this is set to 2 (the default), then for each [interval] there will be
  /// a 1-pixel line on the left, a half-pixel line in the middle, and a 1-pixel
  /// line on the right (the latter being the 1-pixel line on the left of the
  /// next [interval]).
  final int divisions;

  /// The number of minor divisions within each major division, including the
  /// major division itself.
  ///
  /// If [subdivisions] is 5 (the default), it means that there will be four
  /// lines between each major ([divisions]) line.
  ///
  final int subdivisions;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _GridPaperPainter(
        color: color,
        interval: interval,
        divisions: divisions,
        subdivisions: subdivisions,
      ),
      child: child,
    );
  }
}

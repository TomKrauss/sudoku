// The MIT License (MIT)
//
// Copyright © 2026 <copyright holders>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import 'package:flutter/material.dart';

class _GridPaperPainter extends CustomPainter {
  const _GridPaperPainter({
    required this.color,
    required this.interval,
    required this.divisions,
    required this.majorGridColumnBreaks,
    required this.majorGridRowBreaks,
    this.getCellContents
  });

  ///
  /// An optional callback providing an icon to be displayed in the center of each grid cell painted.
  ///
  final String? Function(int row, int column)? getCellContents;

  final Color color;
  final double interval;
  final int divisions;
  ///
  /// The positions, where a major grid line is being painted in column direction.
  ///
  final List<int> majorGridColumnBreaks;

  ///
  /// The positions, where a major grid line is being painted in row direction.
  ///
  final List<int> majorGridRowBreaks;


  @override
  void paint(Canvas canvas, Size size) {
    final thick = 2.0;
    final Paint linePaint = Paint()..color = color;
    linePaint.strokeCap = StrokeCap.round;
    final allDivisions = divisions;
    var gridWidth = interval/allDivisions;
    for (int x = 0; x <= allDivisions; x ++) {
      bool isBreak = majorGridColumnBreaks.contains(x);
      linePaint.strokeWidth =
      (x % allDivisions == 0)
          ? thick
          : isBreak
          ? 1.5
          : 0.5;
      var xPos = x*size.width/allDivisions;
      if (x == 0) {
        xPos++;
      }
      if (x == allDivisions) {
        xPos--;
      }
      canvas.drawLine(Offset(xPos, 1), Offset(xPos, size.height-1), linePaint);
    }
    for (int y = 0; y <= allDivisions; y++) {
      bool isBreak = majorGridRowBreaks.contains(y);
      linePaint.strokeWidth =
      (y % allDivisions == 0)
          ? thick
          : isBreak
          ? 1.5
          : 0.5;
      var yPos = y * size.height / allDivisions;
      if (y == 0) {
        yPos++;
      }
      if (y == allDivisions) {
        yPos--;
      }
      canvas.drawLine(Offset(1, yPos), Offset(size.width-1, yPos), linePaint);
    }
    var f = getCellContents;
    if (f != null) {
      for (int x = 0; x < allDivisions; x ++) {
        var xPos = x*interval/allDivisions;
        for (int y = 0; y < allDivisions; y++) {
          var yPos = y * size.height / allDivisions;
          var text = f(x, y);
          if (text != null) {
            TextPainter textPainter = TextPainter(textDirection: TextDirection.rtl, textAlign: TextAlign.center, );
            textPainter.text = TextSpan(text: text,
                style: TextStyle(fontSize: gridWidth > 10 ? gridWidth/2 : gridWidth, color: Colors.grey));
            textPainter.layout();
            textPainter.paint(canvas, Offset(xPos+gridWidth/4,yPos + gridWidth/4));
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GridPaperPainter oldPainter) => oldPainter.color != color ||
        oldPainter.interval != interval ||
        oldPainter.divisions != divisions ||
        oldPainter.majorGridColumnBreaks != majorGridColumnBreaks ||
      oldPainter.majorGridRowBreaks != majorGridRowBreaks;

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
    this.color = Colors.black,
    this.interval = 100.0,
    this.divisions = 10,
    this.majorGridColumnBreaks = const [5],
    this.majorGridRowBreaks = const [5],
    this.getCellContents,
    this.child,
  });

  ///
  /// An optional callback providing an icon to be displayed in the center of each grid cell painted.
  ///
  final String? Function(int row, int column)? getCellContents;

  /// The color to draw the lines in the grid.
  ///
  /// Defaults to a light blue commonly seen on traditional grid paper.
  final Color color;

  /// The distance between the primary lines in the grid, in logical pixels.
  ///
  /// Each primary line is one logical pixel wide.
  final double interval;

  /// The number of divisions within each grid cell.
  ///
  /// This is the number of divisions per [interval], including the
  /// primary grid's line.
  ///
  /// The lines after the first are half a logical pixel wide.
  ///
  /// If this is set to 2 (the default), then for each [interval] there will be
  /// a 1-pixel line on the left, a half-pixel line in the middle, and a 1-pixel
  /// line on the right (the latter being the 1-pixel line on the left of the
  /// next [interval]).
  final int divisions;

  ///
  /// The positions, where a major grid line is being painted in column direction.
  ///
  final List<int> majorGridColumnBreaks;

  ///
  /// The positions, where a major grid line is being painted in row direction.
  ///
  final List<int> majorGridRowBreaks;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
      foregroundPainter: _GridPaperPainter(
        color: color,
        interval: interval,
        divisions: divisions,
        getCellContents: getCellContents,
        majorGridColumnBreaks: majorGridColumnBreaks,
        majorGridRowBreaks: majorGridRowBreaks,
      ),
      child: child,
    );
}

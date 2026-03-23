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
import 'package:flutter/services.dart';
import 'package:sudoku/matrix.dart';


///
/// Widget displaying one cell in the Sudoku board.
///
class CellWidget extends StatelessWidget {
  final bool showTips;
  final FocusNode focusNode;
  final double cellSize;
  final TextInputFormatter inputFilter;
  const CellWidget(this.cell, this.onChanged,
      {required this.showTips, required this.focusNode, required this.editable,
        required this.cellSize, super.key, required this.onToggleCellMark, required this.inputFilter});
  final Cell cell;
  final void Function(String? newVal)? onChanged;
  final void Function() onToggleCellMark;
  final bool editable;

  double get fontSize => cellSize / 3;

  Widget? get editWidget => editable ? TextField(
    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: fontSize),
    decoration: InputDecoration(border: InputBorder.none, counterText: ""),
    textAlign: TextAlign.center,
    focusNode: focusNode,
    selectAllOnFocus: true,
    controller: TextEditingController(text: "${cell.value ?? ''}"),
    onChanged: onChanged,
    onSubmitted: (s) => onToggleCellMark(),
    inputFormatters: [inputFilter],
    keyboardType: TextInputType.number,
  ) : null;

  Color get textColor {
    if (showTips && cell.falselySolved) {
      return Colors.purple;
    }
    if (showTips && cell.hasError) {
      return Colors.red;
    }
    if (cell.given) {
      return Colors.black;
    }
    if (cell.solved) {
      return Colors.blue;
    }
    return Colors.blueGrey;
  }

  TextStyle get textStyle => TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.bold,
    color: textColor,
  );

  Widget get falseGuessWidget => Row(mainAxisAlignment: MainAxisAlignment.center,
    children: [Text("${cell.falseGuess}", style: TextStyle(decoration: TextDecoration.lineThrough), ),
    Icon(Icons.arrow_right_alt, size: fontSize*2/3,),
    Text("${cell.value}", style: textStyle,)],);

  List<String> get alternatives {
    var l = cell.alternatives;
    if (l.length > 7) {
      var result = l.sublist(0, 6).map((i) => " $i ").toList();
      result.add("...");
      return result;
    }
    return l.map((i) => " $i ").toList();
  }

  Widget get contentWidget => cell.value == null && showTips
      ? (Wrap(
    children: alternatives
        .map((text) => Text(text, style: TextStyle(fontSize: fontSize/2)))
        .toList(),
  ))
      : cell.falseGuess != null ? falseGuessWidget : Text(
    "${cell.value ?? ''}",
    style: textStyle,
  );

  @override
  Widget build(BuildContext context) => GestureDetector(
      onDoubleTap: onToggleCellMark,
      child: Container(
          width: cellSize,
          height: cellSize,
          alignment: Alignment.center,
          child:
          Stack(children:
          [?editWidget,
            if (cell.value == null || !editable) contentWidget,
            if (cell.markedAsFound) Container(decoration: ShapeDecoration(shape: CircleBorder(side: BorderSide(width: 2.0))),)
          ],

          )
      ));
}


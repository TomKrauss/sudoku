import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sudoku/model.dart';


///
/// Widget displaying one cell in the Sudoku board.
///
class CellWidget extends StatelessWidget {
  final bool showTips;
  final FocusNode focusNode;
  final double cellSize;
  const CellWidget(this.cell, this.onChanged,
      {required this.showTips, required this.focusNode, required this.editable, required this.cellSize, super.key, required this.onToggleCellMark});
  final Cell cell;
  final void Function(String? newVal)? onChanged;
  final void Function() onToggleCellMark;
  final bool editable;

  Widget? get editWidget => editable ? TextField(
    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
    decoration: InputDecoration(border: InputBorder.none, counterText: ""),
    textAlign: TextAlign.center,
    focusNode: focusNode,
    selectAllOnFocus: true,
    maxLength: 1,
    controller: TextEditingController(text: "${cell.value ?? ''}"),
    onChanged: onChanged,
    onSubmitted: (s) => onToggleCellMark(),
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textColor,
  );

  Widget get falseGuessWidget => Row(mainAxisAlignment: MainAxisAlignment.center,
    children: [Text("${cell.falseGuess}", style: TextStyle(decoration: TextDecoration.lineThrough), ),
    Icon(Icons.arrow_right_alt, size: 12,),
    Text("${cell.value}", style: textStyle,)],);

  Widget get contentWidget => cell.value == null && showTips
      ? (Wrap(
    children: cell.alternatives
        .map((i) => Text(" $i ", style: TextStyle(fontSize: 10)))
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


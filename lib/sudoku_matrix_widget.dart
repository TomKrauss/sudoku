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
import 'package:sudoku/cell_widget.dart';
import 'package:sudoku/grid_paper.dart';
import 'package:sudoku/matrix.dart';
import 'package:sudoku/model.dart';

///
/// Options affecting the way the board displays the games.
///
class BoardOptions {
  ///
  /// Whether the alternatives should be displayed for each cell.
  ///
  bool showTips = false;

  ///
  /// Whether all cells having a candidate matching the current
  /// cell value should be highlighted.
  ///
  bool highlightCells = false;
}


///
/// A widget displaying the Sudoku Matrix and providing keyboard navigation logic to navigate
/// the Sudoku Cells.
///
class SudokuMatrixWidget extends StatefulWidget {
  final Game localModel;
  final BoardOptions options;
  final double cellSize;
  final void Function() onCurrentGameChanged;
  const SudokuMatrixWidget({super.key, required this.localModel, required this.options, required this.cellSize, required this.onCurrentGameChanged});

  @override
  State<StatefulWidget> createState() => SudokuMatrixWidgetState();
}

class SudokuMatrixWidgetState extends State<SudokuMatrixWidget> {
  bool get editing => playing || creating;
  bool get creating => localModel.gameMode == GameMode.creating;
  bool get creatingGame => localModel.gameMode == GameMode.creating;
  bool get playing => localModel.gameMode == GameMode.playing;
  Game get localModel => widget.localModel;
  BoardOptions get options => widget.options;
  double get cellSize => widget.cellSize;
  final Map<CellPosition, FocusNode> focusNodes = {};
  Cell? focusCell;

  ///
  /// Set the focus to the 1st cell in the board.
  ///
  void focusBoard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final entry in focusNodes.entries) {
        var p = entry.key;
        if (localModel.isCellEditable(p)) {
          entry.value.requestFocus();
          return;
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    for (final n in focusNodes.values) {
      n.dispose();
    }
    focusNodes.clear();
  }

  ///
  /// Returns the focus node for a given cell in a game
  ///
  FocusNode forCell(CellPosition cell, [Cell? c]) =>
      focusNodes.putIfAbsent(cell, () {
        var result = FocusNode();
        result.addListener(() {
          if (c?.value != null && options.highlightCells) {
            if (focusCell != c) {
              setState(() {
                focusCell = c;
              });
            }
          }
        });
        return result;
      });

  CellPosition wrapCellPosition(CellPosition p) {
    final rowLength = localModel.columnCount;
    var newX = p.column;
    var newY = p.row;
    while (newX < 0) {
      newX += rowLength;
      newY--;
    }
    while (newX >= rowLength) {
      newX -= rowLength;
      newY++;
    }
    while (newY < 0) {
      newY += localModel.rowCount;
      newX--;
      if (newX < 0) {
        newX += rowLength;
      }
    }
    while (newY >= localModel.rowCount) {
      newY -= localModel.rowCount;
      newX++;
      if (newX >= rowLength) {
        newX = 0;
      }
    }
    return CellPosition(column: newX, row: newY);
  }

  ///
  /// Move the focus to the next cell with a given delta in cell positions from the current
  /// game cell. It is assumed, that are ordered from left top to bottom right.
  ///
  void moveCellFocusBy(int delta) {
    for (final entry in focusNodes.entries) {
      if (entry.value.hasFocus) {
        var p = entry.key;
        p = wrapCellPosition(
          CellPosition(column: p.column + delta, row: p.row),
        );
        var originalPoint = p;
        while (!localModel.isCellEditable(p)) {
          p = wrapCellPosition(
            CellPosition(column: p.column + delta, row: p.row),
          );
          if (p == originalPoint) {
            return;
          }
        }
        var focusNode = forCell(p);
        focusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var filter = localModel.inputFilter;
    var colorScheme = Theme
        .of(context)
        .colorScheme;
    var matrix = localModel.current;
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(
              LogicalKeyboardKey.arrowUp,
            ): () {
              moveCellFocusBy(-localModel.columnCount);
            },
            const SingleActivator(
              LogicalKeyboardKey.arrowDown,
            ): () {
              moveCellFocusBy(localModel.columnCount);
            },
            const SingleActivator(
              LogicalKeyboardKey.arrowRight,
            ): () {
              moveCellFocusBy(1);
            },
            const SingleActivator(
              LogicalKeyboardKey.arrowLeft,
            ): () {
              moveCellFocusBy(-1);
            },
          },
          child: CustomGridPaper(
            divisions: localModel.gridCount,
            majorGridColumnBreaks:
            matrix?.blockColumnBreaks ?? [3, 6],
            majorGridRowBreaks:
            matrix?.blockRowBreaks ?? [3, 6],

            color:
            (!options.showTips ||
                localModel.current?.solvable == true)
                ? (playing
                ? colorScheme.primary
                : Colors.grey.shade300)
                : colorScheme.error,
            interval: localModel.gridCount * cellSize,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: localModel.cells
                  .map(
                    (l) =>
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: l
                          .map(
                            (c) =>
                            CellWidget(
                              c,
                              editing
                                  ? (s) {
                                localModel
                                    .editCellValue(
                                  c,
                                  s,
                                );
                                widget.onCurrentGameChanged();
                                if (localModel
                                    .gridCount <
                                    10) {
                                  WidgetsBinding
                                      .instance
                                      .addPostFrameCallback((_,) {
                                    moveCellFocusBy(
                                      s?.isEmpty ==
                                          true
                                          ? 0
                                          : 1,
                                    );
                                  });
                                }
                              }
                                  : null,
                              cellSize: cellSize,
                              inputFilter: filter,
                              focusNode: forCell(
                                localModel.placementOf(c),
                                c,
                              ),
                              highlighted:
                              options
                                  .highlightCells &&
                                  (c.alternatives
                                      .contains(
                                    focusCell
                                        ?.value,
                                  ) ||
                                      c.value ==
                                          focusCell
                                              ?.value),
                              showTips:
                              options.showTips ||
                                  localModel.gameMode ==
                                      GameMode.solved,
                              editable:
                              editing &&
                                  (creatingGame ||
                                      !c.given),
                              onToggleCellMark: () {
                                setState(() {
                                  localModel
                                      .toggleCellFoundMarker(
                                    c,
                                  );
                                });
                              },
                            ),
                      )
                          .toList(),
                    ),
              )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

}


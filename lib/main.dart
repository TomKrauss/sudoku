import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sudoku/grid_paper.dart';
import 'package:sudoku/input_dialogs.dart';
import 'package:sudoku/model.dart';

double cellSize = 50;

///
/// Display one cell in the Sudoku board.
///
class CellWidget extends StatelessWidget {
  final bool showAlternatives;
  final FocusNode focusNode;
  const CellWidget(this.cell, this.onChanged, {required this.showAlternatives, required this.focusNode, super.key});
  final Cell cell;
  final Function(String? newVal)? onChanged;

  Widget get editWidget => TextField(
    style: TextStyle(color: cell.hasError ? Colors.red : Colors.black, fontWeight: FontWeight.bold),
    decoration: InputDecoration(border: InputBorder.none, counterText: ""),
    textAlign: TextAlign.center,
    focusNode: focusNode,
    selectAllOnFocus: true,
    maxLength: 1,
    controller: TextEditingController(text: "${cell.value ?? ''}"),
    onChanged: onChanged,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    keyboardType: TextInputType.number,
  );

  Widget get contentWidget => cell.value == null && showAlternatives
      ? (Wrap(
          children: cell.alternatives
              .map((i) => Text(" $i ", style: TextStyle(fontSize: 10)))
              .toList(),
        ))
      : Text(
          "${cell.value ?? ''}",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: cell.hasError
                ? Colors.red
                : (cell.solved ? Colors.blue : Colors.black),
          ),
        );

  @override
  Widget build(BuildContext context) => Container(
    width: cellSize,
    height: cellSize,
    alignment: Alignment.center,
    child: onChanged != null ? ( showAlternatives == true && cell.alternatives.length > 1 ? Stack(children: [editWidget, contentWidget],) : editWidget) : contentWidget,
  );
}

///
/// Main Entry Point into the Sudoku Application
///
void main() {
  runApp(const SudokuApplication());
}

///
/// A widget displaying the Sudoko Application.
///
class SudokuApplication extends StatelessWidget {
  const SudokuApplication({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku Solver',
      debugShowCheckedModeBanner: false,
      home: const SudokuBoard(title: 'Edit a Sudoku and solve it'),
    );
  }
}

///
/// A widget displaying a Sudoku Board.
///
class SudokuBoard extends StatefulWidget {
  const SudokuBoard({super.key, required this.title});
  final String title;

  @override
  State<SudokuBoard> createState() => _SudokuBoardState();
}

class _SudokuBoardState extends State<SudokuBoard> {
  final Map<Point<int>, FocusNode> focusNodes = {};
  bool _showAlternatives = false;
  final games = Games();
  Matrix get model => games.current;
  bool editing = false;

  void initWithSample() {
    setState(() {
      games.useSample();
      editing = false;
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
  /// Returns the focus node for a given cell in a matrix
  ///
  FocusNode forCell(Point<int> cell) => focusNodes.putIfAbsent(cell, () => FocusNode());

  ///
  /// Load a game from the list of games available.
  ///
  Future<void> loadGame() async {
    final gameName = await selectGame(context);
    if (gameName != null) {
      setState(() {
        games.load(gameName);
      });
    }
  }

  void newGame() async {
    var name = await showInputPrompt(context, promptText: "Enter the name of the new game",
        title: "New Game", initialValue: "Game #${games.numberOfGames+1}");
    if (name == null) {
      return;
    }
    setState(() {
      if (!model.isEmpty) {
        games.newGame(name: name);
      }
      editing = true;
    });
  }

  void edit() {
    setState(() {
      if (editing) {
        model.clearGuesses();
        model.recalculateAlternatives();
        model.checkValid;
        editing = false;
      } else {
        model.clearGuesses();
        editing = true;
      }
    });
  }

  ///
  /// Save the list of current games known
  ///
  void save() {
    games.save();
  }

  void solve() {
    setState(() {
      editing = false;
      if (model.solved) {
        model.clearGuesses();
        return;
      }
      var solved = model.solve();
      if (solved != null) {
        games.current = solved;
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("No resolution found.")));
      }
    });
  }

  void recalculateAlternatives() {
    if (_showAlternatives) {
      setState(() {
        model.recalculateAlternatives();
        model.checkValid;
      });
    }
  }

  ///
  /// Move the focus to the next cell with a given delta in cell positions from the current
  /// game cell. It is assumed, that are ordered from left top to bottom right.
  ///
  void moveCellFocusBy(int delta) {
    final rowLength = model.columnCount;
    for (final entry in focusNodes.entries) {
      if (entry.value.hasFocus) {
        var p = entry.key;
        var newX = p.x+delta;
        var newY = p.y;
        while (newX < 0) {
          newX += rowLength;
          newY --;
        }
        while (newX >= rowLength) {
          newX -= rowLength;
          newY ++;
        }
        while(newY < 0) {
          newY += model.rowCount;
        }
        while(newY >= model.rowCount) {
          newY -= model.rowCount;
        }
        var cell = forCell(Point(newX, newY));
        cell.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var buttonStyle = ElevatedButton.styleFrom(minimumSize: Size(150, 35));
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                  moveCellFocusBy(-games.current.columnCount);
                },
                const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                  moveCellFocusBy(games.current.columnCount);
                },
                const SingleActivator(LogicalKeyboardKey.arrowRight): () {
                  moveCellFocusBy(1);
                },
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
                  moveCellFocusBy(-1);
                },
              },
              child: CustomGridPaper(
              divisions: 3,
              subdivisions: 3,
              interval: model.gridCount * cellSize,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: model.cells
                    .map(
                      (l) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: l
                            .map(
                              (c) => CellWidget(
                                c,
                                editing
                                    ? (s) {
                                        c.value = int.tryParse(s ?? "");
                                        recalculateAlternatives();
                                      }
                                    : null,
                                focusNode: forCell(model.placementOf(c)),
                                showAlternatives: _showAlternatives,
                              ),
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
          )),
          SizedBox(height: 20),
          Padding(padding: EdgeInsetsGeometry.all(15),
              child: Text("Current game: ${model.name}, difficulty level ${model.difficultyLevel}", style: Theme.of(context).textTheme.bodySmall,)),
          Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: CheckboxListTile(
                  onChanged: (v) {
                    setState(() {
                      _showAlternatives = v == true;
                    });
                    recalculateAlternatives();
                  },
                  value: _showAlternatives,
                  title: Text("Show Alternatives"),
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            runSpacing: 10,
            spacing: 10,
            children: [
              ElevatedButton(onPressed: solve, style: buttonStyle, child: Text(model.solved ? "Clear Hints" : "Solve")),
              ElevatedButton(onPressed: newGame, style: buttonStyle, child: Text("New")),
              ElevatedButton(onPressed: edit, style: buttonStyle, child: Text("Edit")),
              ElevatedButton(onPressed: save, style: buttonStyle, child: Text("Save")),
              ElevatedButton(onPressed: loadGame, style: buttonStyle, child: Text("Load...")),
              ElevatedButton(onPressed: initWithSample, style: buttonStyle, child: Text("Sample")),
            ],
          ),
        ],
      ),
    );
  }
}

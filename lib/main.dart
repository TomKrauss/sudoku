// The MIT License (MIT)
//
// Copyright © 2026 <copyright holders>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:sudoku/cell_widget.dart';
import 'package:sudoku/grid_paper.dart';
import 'package:sudoku/input_dialogs.dart';
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
/// Main Entry Point into the Sudoku Application
///
Future<void> main() async {
  runApp(const SudokuApplication());
}

///
/// A widget displaying the Sudoko Application.
///
class SudokuApplication extends StatelessWidget {
  const SudokuApplication({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sudoku Solver',
    debugShowCheckedModeBanner: false,
    home: const SudokuBoard(title: 'Sudoku'),
  );
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
  final Map<CellPosition, FocusNode> focusNodes = {};
  BoardOptions options = BoardOptions();
  final games = Games();
  Game? model;
  Cell? focusCell;
  bool _helpPage = false;
  ///
  /// The options most recently selected, when generating new games.
  ///
  NewGameOptions? _newGameOptions;


  @override
  void initState() {
    super.initState();
    games.initialize();
  }

  void initWithSample() {
    setState(() {
      games.useSample();
      model?.gameMode = GameMode.playing;
    });
  }

  bool get creating => model?.gameMode == GameMode.creating;

  bool get editing =>
      model?.gameMode == GameMode.playing || creating;

  bool get playing => model?.gameMode == GameMode.playing;
  bool get creatingGame => model?.gameMode == GameMode.creating;

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

  ///
  /// Load a game from the list of games available.
  ///
  Future<void> loadGame(Game? model) async {
    await _pop();
    if (model?.dirty == true && mounted) {
      var result = await showAlertDialog(
        context,
        message: "Do you want to save the current game?",
        buttons: ["Yes", "No", "Cancel"],
      );
      if (result == "Cancel") {
        return;
      }
      if (result == "Yes") {
        games.save();
      }
      games.markDirty(false);
    }
    if (!mounted) {
      return;
    }
    final gameName = await selectGame(context);
    if (gameName != null) {
      setState(() {
        games.selectGameNamed(gameName);
        onCurrentGameChanged();
      });
    }
  }

  ///
  /// Returns the default options to use, when generating / creating a new game.
  ///
  NewGameOptions get defaultOptions {
    var useOptions = _newGameOptions ?? NewGameOptions();
    useOptions = useOptions.copyWith(name: "Game #${games.games.length + 1}");
    return useOptions;
  }

  ///
  /// Create a new empty game, where the user can type in the numbers by herself.
  ///
  Future<void> newGame() async {
    await _pop();
    var useOptions = defaultOptions;
    if (!mounted) {
      return;
    }
    var options = await selectNewGameOptions(context, title: "Create new empty Game", options: useOptions, generateGame: false);
    if (options == null) {
      return;
    }
    _newGameOptions = options;
    setState(() {
      games.newGame(name: options.name, size: options.gridSize);
    });
  }

  void _generateGame(NewGameOptions options) {
    games.generateGame(
      level: options.difficulty.level,
      name: options.name,
      size: options.gridSize,
    );
  }

  ///
  /// Create a new empty game and generate the game with options to select before .
  ///
  Future<void> generateGame() async {
    await _pop();
    if (!mounted) {
      return;
    }
    var useOptions = defaultOptions;
    var options = await selectNewGameOptions(context, title: "Generate Game", options: useOptions, generateGame: true);
    if (options == null) {
      return;
    }
    _newGameOptions = options;
    _generateGame(options);
  }

  ///
  /// Pop the end drawer off the screen.
  ///
  Future<void> _pop() async {
    await Navigator.of(context).maybePop();
  }

  ///
  /// Start or stop editing the game.
  /// If [create] is true, this is done to define a game manually, if it
  /// is false, we start to solve the Sudoku manually.
  ///
  void edit({bool create = false}) {
    _pop();
    setState(() {
      model?.gameMode = create ? GameMode.creating : GameMode.playing;
    });
    focusBoard();
  }

  ///
  /// Save the list of current games known
  ///
  void save() {
    _pop();
    games.save();
  }

  ///
  /// Display the help page or hide it.
  ///
  void toggleHelp() {
    _pop();
    setState(() {
      _helpPage = !_helpPage;
    });
  }

  ///
  /// Calculate the solution and show the result.
  ///
  Future<void> showSolution(Game? model) async {
    if (model == null) {
      return;
    }
    await _pop();
    if (model.gameMode == GameMode.solved) {
      model.gameMode = GameMode.playing;
    } else {
      model.gameMode = GameMode.solved;
      if (model.current == null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("No resolution found.")));
      }
    }
    onCurrentGameChanged();
    setState(() {});
  }

  ///
  /// Invoked, when a new game is loaded / selected or edited by the user.
  /// Will update the model depending on the current options selected and e.g.
  /// check the validity of the matrix and alternate values for each cell.
  ///
  void onCurrentGameChanged() {
    if (options.showTips) {
      setState(() {
        model?.onChanged();
      });
    }
  }

  CellPosition wrapCellPosition(CellPosition p) {
    final rowLength = model?.columnCount;
    if (rowLength == null) {
      return p;
    }
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
      newY += model!.rowCount;
      newX--;
      if (newX < 0) {
        newX += rowLength;
      }
    }
    while (newY >= model!.rowCount) {
      newY -= model!.rowCount;
      newX++;
      if (newX >= rowLength) {
        newX = 0;
      }
    }
    return CellPosition(column: newX, row: newY);
  }

  ///
  /// Set the focus to the 1st cell in the board.
  ///
  void focusBoard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final entry in focusNodes.entries) {
        var p = entry.key;
        if (model?.isCellEditable(p) == true) {
          entry.value.requestFocus();
          return;
        }
      }
    });
  }

  ///
  /// Move the focus to the next cell with a given delta in cell positions from the current
  /// game cell. It is assumed, that are ordered from left top to bottom right.
  ///
  void moveCellFocusBy(int delta) {
    for (final entry in focusNodes.entries) {
      if (entry.value.hasFocus) {
        var p = entry.key;
        p = wrapCellPosition(CellPosition(column: p.column + delta, row: p.row));
        var originalPoint = p;
        while (model?.isCellEditable(p) == false) {
          p = wrapCellPosition(CellPosition(column: p.column + delta, row: p.row));
          if (p == originalPoint) {
            return;
          }
        }
        var focusNode = forCell(p);
        focusNode.requestFocus();
      }
    }
  }

  ButtonStyle get buttonStyle =>
      ElevatedButton.styleFrom(minimumSize: Size(165, 35));

  Future<String> _loadHelpFile() => rootBundle.loadString("lib/assets/help.md");

  Widget get helpArea => FutureBuilder(
    future: _loadHelpFile(),
    builder: (context, snapshot) => Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: snapshot.data == null
                ? Text("")
                : MarkdownWidget(data: snapshot.data!),
          ),
          ElevatedButton(
            onPressed: toggleHelp,
            style: buttonStyle,
            child: Text("Back to Game"),
          ),
        ],
      ),
    ),
  );

  Widget get contentArea {
    var width = (MediaQuery.widthOf(context) - 50);
    var height = (MediaQuery.heightOf(context) - 130);
    return StreamBuilder(
      stream: games.current,
      builder: (context, snapshot) {
        var localModel = snapshot.data;
        if (localModel == null) {
          return Center(
            child: Card(
              margin: EdgeInsets.all(20),
              child: Padding(
                padding: EdgeInsetsGeometry.all(50),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Operation in Progress. Please wait."),
                    SizedBox(height: 20),
                    CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          );
        }
        model = localModel;
        var cellSize = (height > width ? width : height) / localModel.gridCount;
        var matrix = localModel.current;
        void f(c) {
          setState(() {});
        }
        matrix?.onCellErrorStateChanged = f;
        matrix?.onChanged = f;
        var filter = localModel.inputFilter;
        var colorScheme = Theme.of(context).colorScheme;
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CallbackShortcuts(
                  bindings: <ShortcutActivator, VoidCallback>{
                    const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                      moveCellFocusBy(-localModel.columnCount);
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                      moveCellFocusBy(localModel.columnCount);
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowRight): () {
                      moveCellFocusBy(1);
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
                      moveCellFocusBy(-1);
                    },
                  },
                  child: CustomGridPaper(
                    divisions: localModel.gridCount,
                    majorGridColumnBreaks: matrix?.blockColumnBreaks ?? [3, 6],
                    majorGridRowBreaks: matrix?.blockRowBreaks ?? [3, 6],

                    color: (!options.showTips || localModel.current?.solvable == true)
                        ? (playing ? colorScheme.primary : Colors.grey.shade300)
                        : colorScheme.error,
                    interval: localModel.gridCount * cellSize,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: localModel.cells
                          .map(
                            (l) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: l
                                  .map(
                                    (c) => CellWidget(
                                      c,
                                      editing
                                          ? (s) {
                                              localModel.editCellValue(c, s);
                                              onCurrentGameChanged();
                                              if (localModel.gridCount < 10) {
                                                WidgetsBinding.instance
                                                    .addPostFrameCallback((_) {
                                                      moveCellFocusBy(
                                                        s?.isEmpty == true
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
                                        localModel.placementOf(c),c
                                      ),
                                      highlighted: options.highlightCells && (c.alternatives.contains(focusCell?.value) || c.value == focusCell?.value),
                                      showTips:
                                          options.showTips ||
                                          localModel.gameMode ==
                                              GameMode.solved,
                                      editable:
                                          editing && (creatingGame || !c.given),
                                      onToggleCellMark: () {
                                        setState(() {
                                          localModel.toggleCellFoundMarker(c);
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
              ),
              SizedBox(height: 20),
              Padding(
                padding: EdgeInsetsGeometry.all(15),
                child: Text(
                  "${playing
                      ? 'Playing'
                      : editing
                      ? 'Editing'
                      : 'Selected'} '${localModel.name}'. Difficulty level ${localModel.difficultyLevel}",
                ),
              )
        ]));
      },
    );
  }

  Widget get drawer => Drawer(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(
            onPressed: () => loadGame(model),
            style: buttonStyle,
            child: Text("Select Game..."),
          ),
          ElevatedButton(
            onPressed: () => edit(create: !creating),
            style: buttonStyle,
            child: Text(creating ? "Play" : "Edit"),
          ),
          ElevatedButton(
            onPressed: generateGame,
            style: buttonStyle,
            child: Text("Generate Game..."),
          ),
          ElevatedButton(
            onPressed: newGame,
            style: buttonStyle,
            child: Text("New Game..."),
          ),
          ElevatedButton(
            onPressed: save,
            style: buttonStyle,
            child: Text("Save"),
          ),
          Divider(),
          ElevatedButton(
            onPressed: toggleHelp,
            style: buttonStyle,
            child: Text(_helpPage ? "Back to Game" : "Help"),
          ),
          ElevatedButton(
            onPressed: () => showSolution(model),
            style: buttonStyle,
            child: Text(
              model?.gameMode == GameMode.solved
                  ? "Clear Solution Hints"
                  : "Show Solution",
            ),
          ),
          Flexible(
            child: CheckboxListTile(
              onChanged: (v) {
                setState(() {
                  options.showTips = v == true;
                });
                onCurrentGameChanged();
              },
              value: options.showTips,
              title: Text("Show Tips"),
            ),
          ),
          Flexible(
            child: CheckboxListTile(
              onChanged: (v) {
                setState(() {
                  options.highlightCells = v == true;
                });
                onCurrentGameChanged();
              },
              value: options.highlightCells,
              title: Text("Highlight Cells"),
            ),
          ),

        ],));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    endDrawer: drawer,
    body: _helpPage
        ? helpArea
        : contentArea
  );
}

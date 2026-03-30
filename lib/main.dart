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
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:sudoku/cell_widget.dart';
import 'package:sudoku/grid_paper.dart';
import 'package:sudoku/input_dialogs.dart';
import 'package:sudoku/model.dart';

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
      home: const SudokuBoard(title: 'Edit a Sudoku and solve it'),
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
  final Map<Point<int>, FocusNode> focusNodes = {};
  bool _showTips = false;
  final games = Games();
  Game? model;
  bool _helpPage = false;
  late Future<Object?> initialize;

  @override
  void initState() {
    super.initState();
    initialize = games.initialize();
  }

  void initWithSample() {
    setState(() {
      games.useSample();
      model?.gameMode = GameMode.playing;
    });
  }

  bool get editing => model?.gameMode == GameMode.playing || model?.gameMode == GameMode.creating;
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
  FocusNode forCell(Point<int> cell) => focusNodes.putIfAbsent(cell, FocusNode.new);

  ///
  /// Load a game from the list of games available.
  ///
  Future<void> loadGame(Game model) async {
    if (model.dirty) {
      var result = await showAlertDialog(context, message: "Do you want to save the current game?", buttons: ["Yes", "No", "Cancel"]);
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
  /// Create a new empty game, where the user can type in the numbers by herself.
  ///
  Future<void> newGame() async {
    var options = await selectNewGameOptions(context, generateGame: false);
    if (options == null) {
      return;
    }
    setState(() {
      games.newGame(name: options.name, size: options.gridSize);
    });
  }

  void _generateGame(NewGameOptions options) {
    games.generateGame(numberOfEmptyPlaces: options.numberOfEmptyPlaces,
          name: options.name,
          size: options.gridSize);
  }

  ///
  /// Create a new empty game and generate the game with options to select before .
  ///
  Future<void> generateGame(Game model) async {
    var options = await selectNewGameOptions(context, generateGame: true);
    if (options == null) {
      return;
    }
    _generateGame(options);
  }

  ///
  /// Start or stop editing the game.
  /// If [create] is true, this is done to define a game manually, if it
  /// is false, we start to solve the Sudoku manually.
  ///
  void edit({bool create = false}) {
    setState(() {
      model?.gameMode = create ? GameMode.creating : GameMode.playing;
    });
    focusBoard();
  }

  ///
  /// Save the list of current games known
  ///
  void save() {
    games.save();
  }

  ///
  /// Display the help page or hide it.
  ///
  void toggleHelp() {
    setState(() {
      _helpPage = !_helpPage;
    });
  }

  ///
  /// Calculate the solution and show the result.
  ///
  Future<void> showSolution(Game model) async {
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
    setState(() {

    });
  }

  ///
  /// Invoked, when a new game is loaded / selected or edited by the user.
  /// Will update the model depending on the current options selected and e.g.
  /// check the validity of the matrix and alternate values for each cell.
  ///
  void onCurrentGameChanged() {
    if (_showTips) {
      setState(() {
        model?.onChanged();
      });
    }
  }

  Point<int> wrapPoint(Point<int> p) {
    final rowLength = model?.columnCount;
    if (rowLength == null) {
      return p;
    }
    var newX = p.x;
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
      newY += model!.rowCount;
      newX--;
      if (newX < 0) {
        newX += rowLength;
      }
    }
    while(newY >= model!.rowCount) {
      newY -= model!.rowCount;
      newX++;
      if (newX >= rowLength) {
        newX = 0;
      }
    }
    return Point(newX, newY);
  }

  ///
  /// Set the focus to the 1st cell in the board.
  ///
  void focusBoard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final entry in focusNodes.entries) {
        var p = entry.key;
        if (model?.isCellEditable(p.x, p.y) == true) {
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
        p = wrapPoint(Point(p.x+delta, p.y));
        var originalPoint = p;
        while (model?.isCellEditable(p.x, p.y) == false) {
          p = wrapPoint(Point(p.x+delta, p.y));
          if (p == originalPoint) {
            return;
          }
        }
        var cell = forCell(p);
        cell.requestFocus();
      }
    }
  }

  ButtonStyle get buttonStyle => ElevatedButton.styleFrom(minimumSize: Size(165, 35));

  Future<String> _loadHelpFile() => rootBundle.loadString("lib/assets/help.md");

  Widget get helpArea =>
    FutureBuilder(future: _loadHelpFile(), builder: (context, snapshot) =>
      Padding(padding: EdgeInsets.all(10), child: Column(children: [
        Expanded(
            child: snapshot.data == null ? Text("") : MarkdownWidget(data: snapshot.data!)),
        ElevatedButton(onPressed: toggleHelp,
            style: buttonStyle,
            child: Text("Back to Game")),
      ])));


  Widget get contentArea {
    var width = (MediaQuery.widthOf(context) - 50);
    var height = (MediaQuery.heightOf(context) - 300);
    return StreamBuilder(stream: games.current, builder: (context, snapshot) {
      var localModel = snapshot.data;
      if (localModel == null) {
        return Center(child: Column(children: [Text("Operation in Progress. Please wait."), SizedBox(height: 20), CircularProgressIndicator()]));
      }
      model = localModel;
      var cellSize = (height > width ? width : height) / localModel.gridCount;
      var matrix = localModel.current;
      matrix?.onCellErrorStateChanged = (c) {
        setState(() {

        });
      };
      var filter = localModel.inputFilter;
      var colorScheme = Theme
          .of(context)
          .colorScheme;
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
                  color: (!_showTips || localModel.current?.solvable == true)
                      ? colorScheme.primary
                      : colorScheme.onError,
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
                                      localModel.editCellValue(c, s);
                                      onCurrentGameChanged();
                                      if (localModel.gridCount < 10) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          moveCellFocusBy(
                                              s?.isEmpty == true ? 0 : 1);
                                        });
                                      }
                                    }
                                        : null,
                                    cellSize: cellSize,
                                    inputFilter: filter,
                                    focusNode: forCell(localModel.placementOf(c)),
                                    showTips: _showTips ||
                                        localModel.gameMode == GameMode.solved,
                                    editable: editing &&
                                        (creatingGame || !c.given),
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
              )),
          SizedBox(height: 20),
          Padding(padding: EdgeInsetsGeometry.all(15),
              child: Text("${playing ? 'Playing' : editing
                  ? 'Editing'
                  : 'Selected'} game: ${localModel.name}, difficulty level ${localModel
                  .difficultyLevel}",
                style: Theme
                    .of(context)
                    .textTheme
                    .bodySmall,)),
          Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: CheckboxListTile(
                  onChanged: (v) {
                    setState(() {
                      _showTips = v == true;
                    });
                    onCurrentGameChanged();
                  },
                  value: _showTips,
                  title: Text("Show Tips"),
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            runSpacing: 10,
            spacing: 10,
            children: [
              ElevatedButton(onPressed: () => loadGame(localModel),
                  style: buttonStyle,
                  child: Text("Select Game...")),
              ElevatedButton(onPressed: () => edit(create: false),
                  style: buttonStyle,
                  child: Text("Play")),
              ElevatedButton(onPressed: () => generateGame(localModel),
                  style: buttonStyle,
                  child: Text("Generate Game...")),
              ElevatedButton(onPressed: () => showSolution(localModel),
                  style: buttonStyle,
                  child: Text(localModel.gameMode == GameMode.solved
                      ? "Clear Hints"
                      : "Show Solution")),
              ElevatedButton(onPressed: newGame,
                  style: buttonStyle,
                  child: Text("New Game...")),
              ElevatedButton(onPressed: () => edit(create: true),
                  style: buttonStyle,
                  child: Text("Edit Game")),
              ElevatedButton(
                  onPressed: save, style: buttonStyle, child: Text("Save")),
              ElevatedButton(
                  onPressed: toggleHelp,
                  style: buttonStyle,
                  child: Text("Help")),
            ],
          ),
        ],
      ));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _helpPage ? helpArea : FutureBuilder(future: initialize, builder: (context, snapshot) {
        if (snapshot.data == null) {
          return CircularProgressIndicator();
        }
        return contentArea;
      })
  );
}

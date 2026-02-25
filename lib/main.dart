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
  bool _showAlternatives = false;
  final games = Games();
  Game get model => games.current;
  bool _helpPage = false;
  void initWithSample() {
    setState(() {
      games.useSample();
      model.gameMode = GameMode.playing;
    });
  }

  bool get editing => model.gameMode == GameMode.playing || model.gameMode == GameMode.creating;
  bool get playing => model.gameMode == GameMode.playing;
  bool get creatingGame => model.gameMode == GameMode.creating;

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
  /// Generate a new Sudoku game - to be implemented.
  ///
  Future<void> generate() async {
    await showAlertDialog(context, message: "Generating Sudoku Games is not yet implemented.", buttons: ["OK"]);
  }

  ///
  /// Load a game from the list of games available.
  ///
  Future<void> loadGame() async {
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

  Future<void> newGame() async {
    var name = await showInputPrompt(context, promptText: "Enter the name of the new game",
        title: "New Game", initialValue: "Game #${games.numberOfGames+1}");
    if (name == null) {
      return;
    }
    setState(() {
      if (!model.isEmpty) {
        games.newGame(name: name);
      }
    });
  }

  ///
  /// Start or stop editing the game.
  /// If [create] is true, this is done to define a game manually, if it
  /// is false, we start to solve the Sudoku manually.
  ///
  void edit({bool create = false}) {
    setState(() {
      model.gameMode = create ? GameMode.creating : GameMode.playing;
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

  void showSolution() {
    setState(() {
      if (model.gameMode == GameMode.solved) {
        model.gameMode = GameMode.playing;
      } else {
        model.gameMode = GameMode.solved;
        if (model.current == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("No resolution found.")));
        }
      }
      onCurrentGameChanged();
    });
  }

  ///
  /// Invoked, when a new game is loaded / selected or edited by the user.
  /// Will update the model depending on the current options selected and e.g.
  /// check the validity of the matrix and alternate values for each cell.
  ///
  void onCurrentGameChanged() {
    if (_showAlternatives) {
      setState(() {
        model.onChanged();
      });
    }
  }

  Point<int> wrapPoint(Point<int> p) {
    final rowLength = model.columnCount;
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
      newY += model.rowCount;
      newX--;
      if (newX < 0) {
        newX += rowLength;
      }
    }
    while(newY >= model.rowCount) {
      newY -= model.rowCount;
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
        if (model.isCellEditable(p.x, p.y)) {
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
        while (!model.isCellEditable(p.x, p.y)) {
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

  ButtonStyle get buttonStyle => ElevatedButton.styleFrom(minimumSize: Size(150, 35));

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
    var cellSize = (height > width ? width : height) / games.current.gridCount;
    return SingleChildScrollView(child: Column(
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
                                    model.editCellValue(c, s);
                                    onCurrentGameChanged();
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      moveCellFocusBy(
                                          s?.isEmpty == true ? 0 : 1);
                                    });
                                  }
                                      : null,
                                  cellSize: cellSize,
                                  focusNode: forCell(model.placementOf(c)),
                                  showAlternatives: _showAlternatives,
                                  editable: editing &&
                                      (creatingGame || !c.given),
                                  onToggleCellMark: () {
                                    setState(() {
                                      model.toggleCellFoundMarker(c);
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
                : 'Selected'} game: ${model.name}, difficulty level ${model
                .difficultyLevel}", style: Theme
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
                    _showAlternatives = v == true;
                  });
                  onCurrentGameChanged();
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
            ElevatedButton(onPressed: loadGame,
                style: buttonStyle,
                child: Text("Select Game...")),
            ElevatedButton(onPressed: () => edit(create: false),
                style: buttonStyle,
                child: Text("Play")),
            ElevatedButton(onPressed: showSolution,
                style: buttonStyle,
                child: Text(model.gameMode == GameMode.solved
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
                onPressed: toggleHelp, style: buttonStyle, child: Text("Help")),
          ],
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _helpPage ? helpArea : contentArea
  );
}

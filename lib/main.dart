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
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:sudoku/camera_widget.dart';
import 'package:sudoku/input_dialogs.dart';
import 'package:sudoku/model.dart';
import 'package:sudoku/sudoku_matrix_widget.dart';

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
    home: const SudokuBoard(),
  );
}

///
/// A widget displaying a Sudoku Board.
///
class SudokuBoard extends StatefulWidget {
  const SudokuBoard({super.key});

  @override
  State<SudokuBoard> createState() => _SudokuBoardState();
}

enum SudokuBodyMode {
  displayHelp,
  displayMatrix,
  displayCamera
}
class _SudokuBoardState extends State<SudokuBoard> {
  String operationText = "Operation in progress";
  final matrixBoardKey = GlobalKey<SudokuMatrixWidgetState>();
  BoardOptions options = BoardOptions();
  final games = Games();
  final vScrollController = ScrollController();
  final hScrollController = ScrollController();
  Game? model;
  SudokuBodyMode _bodyMode = SudokuBodyMode.displayMatrix;

  ///
  /// The options most recently selected, when generating new games.
  ///
  NewGameOptions? _newGameOptions;

  bool get creating => model?.gameMode == GameMode.creating;
  bool get editing => playing || creating;
  bool get playing => model?.gameMode == GameMode.playing;

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

  @override
  void dispose() {
    super.dispose();
    vScrollController.dispose();
    hScrollController.dispose();
  }

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
      this.model = await games.selectGameNamed(gameName);
      setState(onCurrentGameChanged);
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
    var options = await selectNewGameOptions(
      context,
      title: "Create new empty Game",
      options: useOptions,
      generateGame: false,
    );
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
    operationText = "Generating Game";
    var useOptions = defaultOptions;
    var options = await selectNewGameOptions(
      context,
      title: "Generate Game",
      options: useOptions,
      generateGame: true,
    );
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
  Future<void> edit({bool create = false}) async {
    await _pop();
    setState(() {
      model?.gameMode = create ? GameMode.creating : GameMode.playing;
    });
    focusBoard();
  }

  ///
  /// Save the list of current games known
  ///
  Future<void> save() async {
    await _pop();
    games.save();
  }

  ///
  /// Display the help page or hide it.
  ///
  Future<void> toggleHelp() async {
    await _pop();
    setState(() {
      if (_bodyMode != SudokuBodyMode.displayHelp) {
        _bodyMode = SudokuBodyMode.displayHelp;
      } else {
        _bodyMode = SudokuBodyMode.displayMatrix;
      }
    });
  }

  ///
  /// Display the camera to scan a game from a newspaper or the like..
  ///
  void scanGame() {
    _pop();
    setState(() {
      if (_bodyMode != SudokuBodyMode.displayCamera) {
        _bodyMode = SudokuBodyMode.displayCamera;
      } else {
        _bodyMode = SudokuBodyMode.displayMatrix;
      }
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
    operationText = "Solving game";
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
    var m = model?.current;
    if (playing && m != null && m.solved && m.checkValid) {
      showAlertDialog(context, title: "Sudoku", message: "Congratulations. You solved the game.", buttons: [
        "OK"
      ]);
    }
  }

  ///
  /// Set the focus to the 1st cell in the board.
  ///
  void focusBoard() {
    matrixBoardKey.currentState?.focusBoard();
  }

  ButtonStyle get buttonStyle =>
      ElevatedButton.styleFrom(minimumSize: Size(165, 35));

  Future<String> _loadHelpFile() => rootBundle.loadString("lib/assets/help.md");

  Widget get cameraArea => CameraWidget();

  Widget get helpArea => FutureBuilder(
    future: _loadHelpFile(),
    builder: (context, snapshot) => Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
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
    var availWidth = MediaQuery.widthOf(context) - 20;
    var width = availWidth;
    var availHeight = MediaQuery.heightOf(context) - 115;
    if (availWidth < 300) {
      availHeight -= 20;
    }
    var height = availHeight;
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
                    Text("$operationText. Please wait."),
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
        if (cellSize < 40) {
          cellSize = 40;
          width = cellSize * localModel.gridCount;
          height = width;
        }
        if (height > width) {
          height = width;
        } else {
          width = height;
        }
        var matrix = localModel.current;
        void f(c) {
          setState(() {});
        }
        var infoColor = playing ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.secondary;
        var infoFGColor = playing ? Theme.of(context).colorScheme.onTertiary : Theme.of(context).colorScheme.onSecondary;
        matrix?.onCellErrorStateChanged = f;
        matrix?.onChanged = f;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                width: availWidth,
                height: availHeight,
                child: Scrollbar(
                  thumbVisibility: true,
                  thickness: 20,
                  controller: hScrollController,
                  child: SingleChildScrollView(
                    controller: hScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Scrollbar(
                      thumbVisibility: true,
                      thickness: 20,
                      scrollbarOrientation: ScrollbarOrientation.left,
                      controller: vScrollController,
                      child: SingleChildScrollView(
                        controller: vScrollController,
                        scrollDirection: Axis.vertical,
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: SudokuMatrixWidget(key: matrixBoardKey, localModel: localModel,
                              options: options, cellSize: cellSize, onCurrentGameChanged: onCurrentGameChanged),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
                color: infoColor,
                margin: EdgeInsets.only(top: 5),
                child: Padding(
              padding: EdgeInsetsGeometry.all(15),
              child: Row(children: [
                Icon(playing ? Icons.games_outlined : Icons.edit, color: infoFGColor,),
                SizedBox(width: 10),
                Text(
                "${playing || localModel.gameMode == GameMode.solved
                    ? 'Playing Game'
                    : editing
                    ? 'Editing Game'
                    : ''} '${localModel.name}'. Difficulty ${localModel.difficulty} (${localModel.difficultyMetrics})",
                  style: TextStyle(color: infoFGColor),
              )]),
            )),
          ],
        );
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
        if (Platform.isIOS || Platform.isAndroid)
        ElevatedButton(
          onPressed: scanGame,
          style: buttonStyle,
          child: Text(_bodyMode != SudokuBodyMode.displayCamera ? "Scan Game..." : "Back to Game"),
        ),
        Divider(),
        ElevatedButton(
          onPressed: toggleHelp,
          style: buttonStyle,
          child: Text(_bodyMode != SudokuBodyMode.displayHelp ? "Help" : "Back to Game"),
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
      ],
    ),
  );

  Widget get body {
    switch(_bodyMode) {
      case .displayMatrix: return contentArea;
      case .displayHelp: return helpArea;
      case .displayCamera: return cameraArea;
    }
  }

  String get title {
    switch(_bodyMode) {
      case .displayMatrix: return "Sudoku";
      case .displayHelp: return "How to Play";
      case .displayCamera: return "Scan Sudoku from Paper";
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    endDrawer: drawer,
    body: body,
  );
}

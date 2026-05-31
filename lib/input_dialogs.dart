// The MIT License (MIT)
//
// Copyright © 2026 <copyright holders>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sudoku/board_preview_widget.dart';
import 'package:sudoku/matrix.dart';
import 'package:sudoku/model.dart';

const _defaultDialogTitle = "Sudoku";

///
/// A selectable board size.
///
class BoardSize {
  final int gridCount;
  final String baseName;
  BoardSize({required this.gridCount, required this.baseName});

  String get printableName => "$baseName ($gridCount x $gridCount)";

  static final List<BoardSize> supportedSizes = [
    BoardSize(gridCount: 4, baseName: "Child Sudoku"),
    BoardSize(gridCount: 6, baseName: "Mini Sudoku"),
    BoardSize(gridCount: 9, baseName: "Standard"),
    BoardSize(gridCount: 12, baseName: "Maxi Sudoku"),
    BoardSize(gridCount: 16, baseName: "Number Place Challenger"),
    BoardSize(gridCount: 25, baseName: "Giant Sudoku"),
  ];
}

///
/// Options for creating a new game.
///
class NewGameOptions {
  ///
  /// The name to use for the new game.
  ///
  final String name;

  ///
  /// For generated games, the difficulty level of the game
  /// to generate.
  ///
  final Difficulty difficulty;

  ///
  /// The number of cells the game should have.
  ///
  final int gridSize;
  NewGameOptions({
    this.name = "New Game",
    this.difficulty = .easy,
    this.gridSize = 9,
  });

  NewGameOptions copyWith({
    String? name,
    int? gridSize,
    Difficulty? difficulty,
  }) => NewGameOptions(
    name: name ?? this.name,
    gridSize: gridSize ?? this.gridSize,
    difficulty: difficulty ?? this.difficulty,
  );
}

///
/// A widget allowing to define a name and select a difficulty for
/// a game to generate.
///
class NewGameOptionsSelectorWidget extends StatefulWidget {
  final ValueNotifier<NewGameOptions> value;
  final bool generateGame;
  const NewGameOptionsSelectorWidget({
    required this.value,
    this.generateGame = false,
    super.key,
  });

  @override
  State<NewGameOptionsSelectorWidget> createState() =>
      _NewGameOptionsSelectorWidgetState();
}

class _NewGameOptionsSelectorWidgetState
    extends State<NewGameOptionsSelectorWidget> {
  late final TextEditingController controller;
  int gridSize = 9;
  Matrix sampleMatrix = Matrix.empty();
  Difficulty difficulty = Difficulty.easy;

  @override
  void initState() {
    super.initState();
    var options = widget.value.value;
    gridSize = options.gridSize;
    controller = TextEditingController(text: options.name);
    difficulty = options.difficulty;
    updateSampleMatrix();
  }

  void updateSampleMatrix() {
    sampleMatrix = Matrix.empty(size: gridSize);
    final rand = Random();
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (rand.nextBool()) {
          sampleMatrix.setValue(
            CellPosition(row: i, column: j),
            rand.nextInt(gridSize) + 1,
          );
        }
      }
    }
  }

  void updateGameGenerationOptions() {
    widget.value.value = NewGameOptions(
      name: controller.text,
      difficulty: difficulty,
      gridSize: gridSize,
    );
    if (sampleMatrix.gridSize != gridSize) {
      updateSampleMatrix();
    }
  }

  String get _difficultyName => difficulty.name;

  @override
  Widget build(BuildContext context) {
    var width = 300.0;
    var max = MediaQuery.widthOf(context);
    if (width >= max) {
      width = max - 20;
    }
    var previewSize = width - 100;
    return IntrinsicHeight(
      child: SingleChildScrollView(
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Name"),
                  SizedBox(width: 20),
                  Flexible(
                    child: TextField(
                      controller: controller,
                      onChanged: (s) {
                        updateGameGenerationOptions();
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text("Select Board Size"),
              Center(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: previewSize,
                    height: previewSize,
                    child: BoardPreviewWidget(
                      matrix: sampleMatrix,
                      interval: previewSize,
                    ),
                  ),
                ),
              ),
              Center(
                child: DropdownButton<int>(
                  value: gridSize,
                  onChanged: (int? value) {
                    if (value != null) {
                      setState(() {
                        gridSize = value;
                        updateGameGenerationOptions();
                      });
                    }
                  },
                  items: BoardSize.supportedSizes
                      .map<DropdownMenuItem<int>>(
                        (size) => DropdownMenuItem(
                          value: size.gridCount,
                          child: Text(size.printableName),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (widget.generateGame) ...[
                SizedBox(height: 20),
                Text("Difficulty: $_difficultyName"),
                Slider(
                  value: difficulty.level.toDouble(),
                  label: _difficultyName,
                  divisions: Difficulty.values.length,
                  min: Difficulty.easy.level.toDouble(),
                  max: Difficulty.impossible.level.toDouble(),
                  onChanged: (val) {
                    setState(() {
                      difficulty = Difficulty.values[val.toInt()];
                      updateGameGenerationOptions();
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

///
/// A widget displaying a list of games previously saved or added allowing
/// to select one of the games.
///
class GameSelectorWidget extends StatefulWidget {
  final ValueNotifier<String?> value;
  const GameSelectorWidget({required this.value, super.key});

  @override
  State<GameSelectorWidget> createState() => _GameSelectorWidgetState();
}

class _GameSelectorWidgetState extends State<GameSelectorWidget> {
  final games = Games();
  final ScrollController scrollController = ScrollController();
  String? get selection => widget.value.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((x) async {
      await WidgetsBinding.instance.endOfFrame;
      if (games.games.isEmpty) {
        return;
      }
      var maximum = scrollController.position.maxScrollExtent;
      var nGames = games.numberOfGames;
      var idx = games.games.indexWhere((g) => g.name == selection);
      if (idx >= 0) {
        var pos = idx >= nGames-1 ? maximum : ((maximum + scrollController.position.extentInside) / nGames * idx);
        pos = max(0, pos);
        pos = min(pos, maximum);
        scrollController.jumpTo(pos);
      }
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 400,
    height: 300,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Scrollbar(
          controller: scrollController,
          child: ListView(
            controller: scrollController,
            children: games.games.map((g) => ListTile(
                title: Text(g.name ?? ""),
                selected: g.name == selection,
                selectedTileColor: Theme.of(context).colorScheme.primary,
                selectedColor: Theme.of(context).colorScheme.onPrimary,
                onTap: () => setState(() {
                  widget.value.value = g.name;
                }),
              )
          ).toList(),
        ))),
      ],
    ),
  );
}

///
/// General utility to show a dialog.
///
Future<String?> showContentDialog(
  BuildContext context, {
  required String title,
  required Widget content,
  String Function()? getValue,
  List<Widget>? actions,
}) async {
  actions ??= <Widget>[
    TextButton(
      onPressed: () => Navigator.pop(context, null),
      child: const Text('Cancel'),
    ),
    TextButton(
      onPressed: () =>
          Navigator.pop(context, getValue == null ? null : getValue()),
      child: const Text('OK'),
    ),
  ];
  return await showDialog(
    context: context,
    builder: (BuildContext context) =>
        AlertDialog(title: Text(title), content: content, actions: actions),
  );
}

///
/// Show a dialog box allowing to enter a text to be returned and accept using OK or cancel
/// out in which case null is returned.
///
Future<String?> showInputPrompt(
  BuildContext context, {
  String title = _defaultDialogTitle,
  required String promptText,
  String? initialValue,
}) async {
  final controller = TextEditingController(text: initialValue);
  return showContentDialog(
    context,
    title: title,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(promptText),
        Flexible(child: TextField(controller: controller)),
      ],
    ),
    getValue: () => controller.text,
  );
}

///
/// Show a dialog box allowing to display a question, which can be answered using yes/no/cancel ...
///
Future<String?> showAlertDialog(
  BuildContext context, {
  String title = _defaultDialogTitle,
  required String message,
  required List<String> buttons,
}) async => showContentDialog(
  context,
  title: title,
  content: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Text(message)],
  ),
  actions: buttons
      .map(
        (text) => TextButton(
          onPressed: () => Navigator.pop(context, text),
          child: Text(text),
        ),
      )
      .toList(),
);

///
/// Show a dialog allowing to select a game.
///
Future<String?> selectGame(
  BuildContext context, {
  String title = "Select a Sudoku to play",
}) async {
  var n = await Games().current.first;
  final selection = ValueNotifier(n?.name ?? "game");
  final w = GameSelectorWidget(value: selection);
  if (context.mounted) {
    return showContentDialog(
      context,
      title: title,
      content: w,
      getValue: () => selection.value,
    );
  }
  return null;
}

Future<NewGameOptions?> selectNewGameOptions(
  BuildContext context, {
  String title = _defaultDialogTitle,
  required NewGameOptions options,
  required bool generateGame,
}) async {
  final selection = ValueNotifier(options);
  final w = NewGameOptionsSelectorWidget(
    value: selection,
    generateGame: generateGame,
  );
  if (await showContentDialog(
        context,
        title: title,
        content: w,
        getValue: () => "OK",
      ) ==
      "OK") {
    return selection.value;
  }
  return null;
}

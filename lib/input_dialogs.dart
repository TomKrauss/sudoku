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
import 'package:sudoku/model.dart';

const _defaultDialogTitle = "Sudoku";

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
  final int level;

  ///
  /// The number of cells the game should have.
  ///
  final int gridSize;
  NewGameOptions({this.name = "New Game", this.level = 1, this.gridSize = 9});

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
  int level = 0;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value.value.name);
    level = widget.value.value.level;
  }

  void updateGameGenerationOptions() {
    widget.value.value = NewGameOptions(
      name: controller.text,
      level: level,
      gridSize: gridSize,
    );
  }

  @override
  Widget build(BuildContext context) => IntrinsicHeight(child: SizedBox(
    width: 400,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Game name"),
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
        Text("Game Size"),
        Flexible(
          child: RadioGroup(
            onChanged: (int? val) {
              if (val != null) {
                setState(() {
                  gridSize = val;
                  updateGameGenerationOptions();
                });
              }
            },
            groupValue: gridSize,
            child: Column(
              children: [
                RadioListTile(value: 9, title: Text("Standard 9x9")),
                RadioListTile(value: 6, title: Text("Mini Sudoku 6x6")),
                RadioListTile(value: 25, title: Text("Giant Sudoku 25x25")),
                RadioListTile(value: 12, title: Text("Maxi Sudoku 12x12")),
              ],
            ),
          ),
        ),

        if (widget.generateGame) ...[
          SizedBox(height: 20),
          Text("Game Difficulty"),
          Flexible(
            child: RadioGroup(
              onChanged: (int? val) {
                if (val != null) {
                  setState(() {
                    level = val;
                    updateGameGenerationOptions();
                  });
                }
              },
              groupValue: level,
              child: Column(
                children: [
                  RadioListTile(value: 1, title: Text("Beginner Level")),
                  RadioListTile(value: 2, title: Text("Intermediate Level")),
                  RadioListTile(value: 3, title: Text("Expert Level")),
                  RadioListTile(value: 4, title: Text("Killer Level")),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  ));
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
  GlobalKey selectionKey = GlobalKey(debugLabel: "selection");
  String? get selection => widget.value.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((x) {
      var ctx = selectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx);
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
        Text("Select Game to load"),
        Flexible(
          child: ListView(
            children: games.games
                .map(
                  (g) => ListTile(
                    key: g.name == selection ? selectionKey : null,
                    title: Text(g.name ?? ""),
                    selected: g.name == selection,
                    selectedTileColor: Theme.of(context).colorScheme.primary,
                    selectedColor: Theme.of(context).colorScheme.onPrimary,
                    onTap: () => setState(() {
                      widget.value.value = g.name;
                    }),
                  ),
                )
                .toList(),
          ),
        ),
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
  String title = _defaultDialogTitle,
}) async {
  var n = await Games().current.first;
  final selection = ValueNotifier(n?.name ?? "game");
  final w = GameSelectorWidget(value: selection);
  if (context.mounted) {
    return showContentDialog(
      title: title,
      context,
      content: w,
      getValue: () => selection.value,
    );
  }
  return null;
}

Future<NewGameOptions?> selectNewGameOptions(
  BuildContext context, {
  String title = _defaultDialogTitle,
  required bool generateGame
}) async {
  final selection = ValueNotifier(NewGameOptions());
  final w = NewGameOptionsSelectorWidget(value: selection, generateGame: generateGame,);
  if (await showContentDialog(
        title: title,
        context,
        content: w,
        getValue: () => "OK",
      ) ==
      "OK") {
    return selection.value;
  }
  return null;
}

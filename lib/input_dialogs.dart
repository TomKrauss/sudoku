


import 'package:flutter/material.dart';
import 'package:sudoku/model.dart';

const _defaultDialogTitle = "Sudoku";

class GameGenerationOptions {
  final String name;
  final int level;
  final int gridSize;
  GameGenerationOptions({this.name = "New Game", this.level = 1, this.gridSize = 9});

  int get numberOfEmptyPlaces {
    switch(level) {
      case 1: return 42;
      case 2: return 49;
      case 3: return 53;
      default: return 57;
    }
  }
}

///
/// A widget allowing to define a name and select a difficulty for
/// a game to generate.
///
class GameGenerationOptionsSelectorWidget extends StatefulWidget {
  final ValueNotifier<GameGenerationOptions> value;
  const GameGenerationOptionsSelectorWidget({required this.value, super.key});

  @override
  State<GameGenerationOptionsSelectorWidget> createState() => _GameGenerationOptionsSelectorWidgetState();
}

class _GameGenerationOptionsSelectorWidgetState extends State<GameGenerationOptionsSelectorWidget> {
  late final TextEditingController controller;
  bool miniSudoku = false;
  int level = 0;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value.value.name);
    level = widget.value.value.level;
  }

  void updateGameGenerationOptions() {
    widget.value.value = GameGenerationOptions(name: widget.value.value.name, level: level, gridSize: miniSudoku ? 6 : 9);

  }
  @override
  Widget build(BuildContext context) => SizedBox(width: 400, height: 350, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Game name"),
          SizedBox(width: 20),
          Flexible(child: TextField(controller: controller, onChanged: (s) {
            updateGameGenerationOptions();
        },))],),
        CheckboxListTile(value: miniSudoku, onChanged: (v) {
          setState(() {
            miniSudoku = v ?? false;
            updateGameGenerationOptions();
          });
        }, title: Text("Create Mini Sudoku"),),
        SizedBox(height: 20),
        Text("Game Difficulty"),
        ValueListenableBuilder(valueListenable: widget.value, builder: (context, _, _) => Flexible(child:
        RadioGroup(onChanged: (int? val) {
          if (val != null) {
            setState(() {
              level = val;
              updateGameGenerationOptions();
            });
          }
        }, groupValue: level,
            child: Column(children: [
          RadioListTile(value: 1, title: Text("Beginner Level")),
          RadioListTile(value: 2, title: Text("Intermediate Level")),
          RadioListTile(value: 3, title: Text("Expert Level")),
          RadioListTile(value: 4, title: Text("Killer Level"))
        ]))))]));
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
  String? get selection => widget.value.value;

  @override
  Widget build(BuildContext context) => SizedBox(width: 400, height: 300, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
      Text("Select Game to load"),
      Flexible(child: ListView(children: games.games.map((g) =>
        ListTile(title: Text(g.name??""), selected: g.name == selection,
            selectedTileColor: Theme.of(context).colorScheme.primary,
            selectedColor: Theme.of(context).colorScheme.onPrimary,
            onTap: () =>
        setState(() {
          widget.value.value = g.name;
        })
        )).toList(),))]));
}

///
/// General utility to show a dialog.
///
Future<String?> showContentDialog(BuildContext context, {required String title, required Widget content, String Function()?getValue, List<Widget>? actions}) async {
  actions ??= <Widget>[
    TextButton(
      onPressed: () => Navigator.pop(context, null),
      child: const Text('Cancel'),
    ),
    TextButton(onPressed: () => Navigator.pop(context, getValue == null ? null : getValue()), child: const Text('OK')),
  ];
  return await showDialog(context: context, builder: (BuildContext context) => AlertDialog(
    title: Text(title),
    content: content,
    actions: actions,
  ),);
}

///
/// Show a dialog box allowing to enter a text to be returned and accept using OK or cancel
/// out in which case null is returned.
///
Future<String?> showInputPrompt(BuildContext context, {String title = _defaultDialogTitle, required String promptText, String? initialValue}) async {
  final controller = TextEditingController(text: initialValue);
  return showContentDialog(context, title: title, content: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(promptText), Flexible(child: TextField(controller: controller))]), getValue: () => controller.text);
}


///
/// Show a dialog box allowing to display a question, which can be answered using yes/no/cancel ...
///
Future<String?> showAlertDialog(BuildContext context, {String title = _defaultDialogTitle, required String message, required List<String> buttons}) async => showContentDialog(context, title: title, content: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(message)]),
    actions: buttons.map((text) =>
      TextButton(
        onPressed: () => Navigator.pop(context, text),
        child: Text(text),
      )
    ).toList()
  );


///
/// Show a dialog allowing to select a game.
///
Future<String?> selectGame(BuildContext context, {String title = _defaultDialogTitle}) async {
  final selection = ValueNotifier(Games().current.name ?? "game");
  final w = GameSelectorWidget(value: selection);
  return showContentDialog(title: title, context, content: w,
      getValue: () => selection.value);
}


Future<GameGenerationOptions?> selectGameDifficulty(BuildContext context, {String title = _defaultDialogTitle}) async {
  final selection = ValueNotifier(GameGenerationOptions());
  final w = GameGenerationOptionsSelectorWidget(value: selection);
  if (await showContentDialog(title: title, context, content: w,
      getValue: () => "OK") == "OK") {
    return selection.value;
  }
  return null;
}

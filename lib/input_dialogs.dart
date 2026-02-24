


import 'package:flutter/material.dart';
import 'package:sudoku/model.dart';

const _defaultDialogTitle = "Sudoku";

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
Future<String?> selectGame(BuildContext context, {String title = _defaultDialogTitle}) {
  final selection = ValueNotifier(Games().current.name ?? "game");
  final w = GameSelectorWidget(value: selection);
  return showContentDialog(title: title, context, content: w,
      getValue: () => selection.value);
}

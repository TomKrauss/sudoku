


import 'package:flutter/material.dart';

///
/// Show a dialog box allowing to enter a text to be returned and accept using OK or cancel
/// out in which case null is returned.
///
Future<String?> showInputPrompt(BuildContext context, {String title = "Sudoku", required String promptText, String? initialValue}) async {
  final controller = TextEditingController(text: initialValue);
  return await showDialog(context: context, builder: (BuildContext context) => AlertDialog(
    title: Text(title),
    content: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(promptText), Flexible(child: TextField(controller: controller))]),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context, null),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('OK')),
    ],
  ),);
}

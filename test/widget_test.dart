// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.


import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:sudoku/main.dart';
import 'package:sudoku/model.dart';

///
/// Component test of the Sudoku application.
///
void main() {
  Games.logger = Logger(printer: SimplePrinter(printTime: false, colors: false));
  testWidgets('Sudoko Application smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.binding.setSurfaceSize(const Size(1020, 1020));
    await tester.pumpWidget(const SudokuApplication());

    var solve = find.text('Show Solution');
    // Solve game and verify, that all numbers are present 9 times.
    expect(solve, findsOneWidget);
    await tester.tap(solve);
    await tester.pumpAndSettle();
    for (var i = 1; i < 9; i++) {
      expect(find.text('$i'), findsAtLeast(9));
    }
    await tester.pumpAndSettle();
  });
}




import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/model.dart';

///
/// Some unit tests to test operations on the Sudoku model.
///
void main() {
  group("Matrix Tests", () {
    test("Is Empty", () {
      var m = Matrix.empty();
      expect(m.isEmpty, isTrue);
    });
    test("Parse", () {
      var m = Matrix.parse(
          "_ _ _ 8 3 _ _ _ _ "
          "_ _ _ _ 7 4 _ 5 _ "
          "_ _ _ _ _ _ _ _ _ "
          "_ _ 4 _ _ 6 _ _ 8 "
          "2 _ _ _ 8 _ _ _ 9 "
          "_ 6 _ 1 _ 2 4 _ _ "
          "_ _ 5 7 _ _ 9 _ 3 "
          "9 8 _ _ _ _ _ _ 5 "
          "_ _ 1 _ 6 5 _ _ 4 "
      );
      expect(m.valueAt(1, 4), 7);
      expect(m.valueAt(7, 0), 9);
      expect(m.valueAt(8, 8), 4);
      expect(m.difficultyLevel > 3, true);
      var m2 = m.solve();
      expect(m2, isNotNull);
      expect(m2!.valueAt(0, 0), 5);
      expect(m2.valueAt(0, 1), 4);
      expect(m2.checkValid, true);
      m = Matrix.parse(
              "_ 4 2 _ 5 7 _ 8 _ "
              "_ _ _ _ _ _ _ _ 3 "
              "_ _ _ 8 _ 2 _ _ _ "
              "8 _ _ _ 6 _ _ _ 2 "
              "_ 6 _ _ 1 3 _ _ _ "
              "_ _ 7 _ _ _ 5 _ _ "
              "_ 3 _ _ _ 4 _ 2 _ "
              "_ 7 _ _ 2 5 _ _ 1 "
              "_ _ 5 _ _ _ 4 _ _ "
      );
      expect(m.checkValid, true);
      m2 = m.solve();
      expect(m2, isNotNull);
      expect(m2!.checkValid, true);
    });
    test("Generation", () {
      var m1 = Matrix.empty();
      var m2 = m1.generateValidMatrix();
      expect(m2, isNotNull);
      var m3 = Matrix.parse(m2!.debugPrint());
      expect(m3.checkValid, true);
    });
    test("Game Generation", () {
      var m1 = Matrix.empty();
      var nEmpty = 42;
      var m2 = m1.generateGame(numberOfEmptyPlaces: nEmpty);
      expect(m2, isNotNull);
      var m3 = Matrix.parse(m2!.debugPrint());
      expect(m3.checkValid, true);
      expect(m2.valueCount, m2.gridCount*m2.gridCount-nEmpty);
    });
    test("Comparison", () {
      var m1 = Matrix.empty();
      var m2 = Games.sample;
      expect(m1 == m2, isFalse);
      m1 = Games.sample;
      expect(m1 == m2, isTrue);
    });
    test("Validation", () {
      var m = Matrix.empty();
      m.setValue(0, 0, 1);
      m.setValue(0, 1, 1);
      expect(m.checkValid, isFalse);
    });
  });
  group("Games Tests", () {
    test("JSON Encoding", () {
      final games = Games();
      games.clear();
      games.newGame(name: "test");
      var m = games.current.matrix;
      m.setValue(0, 0, 1);
      var encoded = games.asJson();
      var list = games.decodeGames(encoded);
      expect(list.length, 1);
      expect(list[0].name, "test");
    });

  });
}




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
      var m = games.newGame(name: "test");
      m.setValue(0, 0, 1);
      var encoded = games.asJson();
      var list = games.decodeGames(encoded);
      expect(list.length, 1);
      expect(list[0].name, "test");
    });

  });
}




import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:sudoku/matrix.dart';
import 'package:sudoku/model.dart';

///
/// Some unit tests to test operations on the Sudoku model.
///
void main() {
  Games.logger = Logger(printer: SimplePrinter(printTime: false, colors: false));
  group("Matrix Tests", () {
    test("Is Empty", () {
      var m = Matrix.empty();
      expect(m.isEmpty, isTrue);
    });
    test("Block Cells", () {
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
      var cellValues = <List<int>>[];
      m.blocksDo((list) {
        cellValues.add(list.where((c) => c.value != null).map((c) => c.value!).toList());
        return true;
      });
      expect(cellValues.length, 9);
      expect(cellValues[0], <int>[]);
      expect(cellValues[1], <int>[8,3,7,4]);
      expect(cellValues[2], <int>[5]);
      expect(cellValues[3], <int>[4,2,6]);
      expect(cellValues[4], <int>[6,8,1,2]);
      expect(m.blockValues(0, 3), <int>[8,3,7,4]);
      expect(m.blockValues(0, 4), <int>[8,3,7,4]);
      expect(m.blockValues(0, 5), <int>[8,3,7,4]);
      expect(m.blockValues(2, 5), <int>[8,3,7,4]);
      expect(m.blockValues(0, 2), <int>[]);
      expect(m.blockValues(2, 2), <int>[]);
      expect(m.blockValues(3, 2), <int>[4,2,6]);
      expect(m.blockValues(6, 2), <int>[5,9,8,1]);
      expect(m.blockValues(8, 2), <int>[5,9,8,1]);
      expect(m.blockValues(8, 0), <int>[5,9,8,1]);
    });
    test("Unsolvable", () {
      var m = Matrix.parse(
        "7 8 x x x x x 2 x "
        "4 2 x x x 3 x 7 x "
        "9 3 x x x x 8 6 x "
        "1 7 4 9 8 2 3 5 6 "
        "6 9 3 1 7 5 4 8 2 "
        "2 5 8 4 3 6 7 1 9 "
        "5 4 7 3 2 x 6 9 x "
        "8 6 x x x x x 3 x "
        "3 1 x x x x x 4 x ");
      var solved = m.solve();
      expect(solved, isNotNull);

      m = Matrix.parse(
"""
x x x x x 4 x x 6
x x x 2 x 1 x 9 x
x x x x x x x x x
x 6 x x x x x 2 x
x 5 x x x x x 9 8
x x x x x x x 7 x
x x x x x x x x x
x x x x x 2 x x x
x x x 1 x x x x x""");
      solved = m.solve();
      expect(solved, isNull);
    });
    test("Mark falsely solved", () {
      var m = Matrix.parse(
          "x x x x x 4 "
              "x x 3 x 2 x "
              "2 x x x x 5 "
              "1 x x x x 3 "
              "x 1 x 5 x x "
              "5 x x x x x ");
      var mSolved = m.solve();
      expect(mSolved, isNotNull);
      var mGuess = Matrix.parse(
          "2 3 5 1 2 4 "
              "1 3 3 5 2 2 "
              "2 1 2 3 4 5 "
              "1 5 3 2 1 3 "
              "5 1 4 5 1 2 "
              "5 3 2 1 4 5 ");
      mSolved!.markFalselyManualSolvedCells(mGuess);
      expect(mSolved.cells[2][2].falselySolved, true);
    });
    test("Mini Sudoku", () {
      var m = Matrix.parse(
          "x x x x x 4 "
          "x x 3 x 2 x "
          "2 x x x x 5 "
          "1 x x x x 3 "
          "x 1 x 5 x x "
          "5 x x x x x ");
      expect(m.gridCount, 6);
      expect(m.blockRowBreaks, [2,4]);
      var m2 = Matrix.clone(m);
      expect(m2.gridCount, 6);
      expect(m2.blockRowBreaks, [2,4]);
      var mSolved = m2.solve();
      expect(mSolved, isNotNull);
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
      expect(m.difficultyLevel, 10);
      var m21 = Matrix.parse(
          "_ _ _ 8 3 _ _ _ _ "
          "_ _ _ _ _ 4 _ _ _ "
          "_ _ _ _ _ _ _ _ _ "
          "_ _ 4 _ _ 6 _ _ 8 "
          "2 _ _ _ _ _ _ _ 9 "
          "_ 6 _ _ _ 2 _ _ _ "
          "_ _ _ 7 _ _ 9 _ 3 "
          "9 _ _ _ _ _ _ _ 5 "
          "_ _ 1 _ _ _ _ _ 4 "
      );
      expect(m21.difficultyLevel > m.difficultyLevel, true);
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
    test("Generation", () async {
      var m1 = Matrix.empty();
      var m2 = await m1.generateValidMatrix();
      expect(m2, isNotNull);
      var m3 = Matrix.parse(m2!.debugPrint());
      expect(m3.checkValid, true);
    });
    test("Game Generation", () async {
      for (final nEmpty in [42, 52, 57, 58, 60]) {
        var c = DateTime.now().millisecondsSinceEpoch;
        var m1 = Matrix.empty();
        var m2 = await m1.generateGame(numberOfEmptyPlaces: nEmpty);
        var size = m1.gridCount;
        if (nEmpty < 58) {
          expect(m2, isNotNull,
              reason: "Cannot generate ${size}x$size game with $nEmpty empty slots.");
          var m3 = Matrix.parse(m2!.debugPrint());
          expect(m3.checkValid, true);
          expect(m2.valueCount, m2.gridCount * m2.gridCount - nEmpty);
        } else if (m2 != null) {
          Games.logger.i("Created valid ${size}x$size game matrix with $nEmpty empty slots in ${(DateTime.now().millisecondsSinceEpoch-c)/1000}sec");
        }
      }
      for (final size in [6, 16]) {
        int n1 = size == 6 ? 15 : 50;
        int n2 = size == 6 ? 20 : 55;
        for (final nEmpty in [n1, n2]) {
          var m1 = Matrix.empty(size: size);
          var m2 = await m1.generateGame(numberOfEmptyPlaces: nEmpty);
          if (m2 != null) {
            Games.logger.i(
                "Created valid ${size}x$size Game Matrix with $nEmpty empty slots");
          } else {
            Games.logger.i(
                "Creating valid ${size}x$size Game Matrix with $nEmpty empty slots failed.");
            break;
          }
        }
      }
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
    test("JSON Encoding", () async {
      final games = Games();
      games.clear();
      games.newGame(name: "test");
      var m = (await games.current.first)?.matrix;
      m!.setValue(0, 0, 1);
      var encoded = games.asJson();
      var list = games.decodeGames(encoded);
      expect(list.length, 1);
      expect(list[0].name, "test");
    });

  });
}

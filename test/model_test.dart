


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
      expect(m.gridSize, 6);
      expect(m.blockRowBreaks, [2,4]);
      var m2 = Matrix.clone(m);
      expect(m2.gridSize, 6);
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
      expect(m.getValue(CellPosition(row: 1, column: 4)), 7);
      expect(m.getValue(CellPosition(row: 7, column: 0)), 9);
      expect(m.getValue(CellPosition(row: 8, column: 8)), 4);
      expect(m.difficultyMetrics, 37);
      expect(m.difficulty, 7);
      m = Matrix.parse(
          "___83____"
          "____74_5_"
          "_________"
          "_04__6__8"
          "2___8___9"
          "_6_1_24__"
          "__57__9_3"
          "98______5"
          "__1_65__4"
      );
      expect(m.getValue(CellPosition(row: 1, column: 4)), 7);
      expect(m.getValue(CellPosition(row: 7, column: 0)), 9);
      expect(m.getValue(CellPosition(row: 8, column: 8)), 4);
      expect(m.difficultyMetrics, 37);
      expect(m.difficulty, 7);
      // Unsolvable matrix
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
      expect(m21.difficultyMetrics > m.difficultyMetrics, true);
      var m2 = m.solve();
      expect(m2, isNotNull);
      m = Matrix.parse(
          "_ 3 _ _ _ _ _ 8 _ "
          "_ _ 5 4 _ 9 _ _ _ "
          "1 _ _ _ _ _ _ 5 _ "
          "7 _ _ 2 1 _ _ _ 5 "
          "_ _ 1 _ _ _ 2 _ _ "
          "8 _ _ _ 3 6 _ _ 7 "
          "9 6 _ _ _ _ _ _ 4 "
          "_ _ _ 6 _ 4 3 _ _ "
          "_ 2 _ _ _ _ _ _ _ "
      );
      expect(m.checkValid, true);
      m2 = m.solve();
      expect(m2, isNotNull);
      expect(m2!.checkValid, true);
    });
    test("Generation", () async {
      var m1 = Matrix.empty();
      var m2 = m1.generateValidMatrix();
      expect(m2, isNotNull);
      var m3 = Matrix.parse(m2!.debugPrint());
      expect(m3.checkValid, true);
    });
    test("Game Generation", () async {
      for (final nEmpty in [42, 52, 57, 58, 60]) {
        var m1 = Matrix.empty();
        var m2 = m1.generateGame(numberOfEmptyPlaces: nEmpty);
        var size = m1.gridSize;
        expect(m2, isNotNull,
            reason: "Cannot generate ${size}x$size game with $nEmpty empty slots.");
        var m3 = Matrix.parse(m2!.debugPrint());
        expect(m3.checkValid, true);
        expect(m2.valueCount, m2.gridSize * m2.gridSize - nEmpty);
      }
      for (final size in [6, 12, 16, 25]) {
        for (final nLevel in [1, 2, 3, 4, 5]) {
          var m1 = Matrix.empty(size: size);
          var nEmpty = m1.numberOfEmptyPlacesForLevel(nLevel);
          var c = DateTime.now().millisecondsSinceEpoch;
          var m2 = m1.generateGame(numberOfEmptyPlaces: nEmpty);
          var ms = DateTime.now().millisecondsSinceEpoch - c;
          if (m2 != null) {
            Games.logger.i(
                "Created valid ${size}x$size Game Matrix with $nEmpty empty slots in $ms[ms]");
          } else {
            fail(
                "Creating valid ${size}x$size Game Matrix with $nEmpty empty slots failed.");
          }
        }
      }
    });
    test("Calculate Alternatives", () {
      var m = Matrix.parse(
    """
    _ 5 _ _ 3 _ _ _ _
    _ 8 _ _ 1 4 _ 5 _
    _ _ 3 _ 2 9 _ _ _
    3 _ 2 _ 9 _ _ _ _
    _ 7 _ 1 _ 5 _ 4 _
    _ _ 5 2 6 7 _ _ _
    _ _ _ 6 4 _ _ _ _
    _ 4 _ _ 8 _ _ 2 _
    _ _ _ _ 5 _ _ _ _
    """);
      m.recalculateAlternatives();
      expect(m.cells[6][0].alternatives.contains(6), false);
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
      m.setValue(CellPosition(), 1);
      m.setValue(CellPosition(row: 0, column: 1), 1);
      expect(m.checkValid, isFalse);
    });
  });
  group('Matrix.empty', () {
    test('creates an empty 9x9 matrix by default', () {
      final matrix = Matrix.empty();

      expect(matrix.gridSize, 9);

      for (var row = 0; row < matrix.gridSize; row++) {
        for (var column = 0; column < matrix.gridSize; column++) {
          final position = CellPosition(row: row, column: column);

          expect(matrix.getValue(position), isNull);
        }
      }
    });

    test('creates an empty matrix with a custom size', () {
      final matrix = Matrix.empty(size: 4);

      expect(matrix.gridSize, 4);

      for (var row = 0; row < matrix.gridSize; row++) {
        for (var column = 0; column < matrix.gridSize; column++) {
          final position = CellPosition(row: row, column: column);

          expect(matrix.getValue(position), isNull);
        }
      }
    });
  });

  group('Matrix.setValue', () {
    test('sets a value at the given position', () {
      final matrix = Matrix.empty();
      final position = CellPosition(row: 0, column: 0);

      matrix.setValue(position, 5);

      expect(matrix.getValue(position), 5);
    });

    test('overwrites an existing value', () {
      final matrix = Matrix.empty();
      final position = CellPosition(row: 2, column: 3);

      matrix.setValue(position, 4);
      matrix.setValue(position, 9);

      expect(matrix.getValue(position), 9);
    });

    test('can set values in different cells independently', () {
      final matrix = Matrix.empty();

      final first = CellPosition(row: 0, column: 0);
      final second = CellPosition(row: 8, column: 8);

      matrix.setValue(first, 1);
      matrix.setValue(second, 9);

      expect(matrix.getValue(first), 1);
      expect(matrix.getValue(second), 9);
    });
  });

  group('Matrix.clearValue', () {
    test('clears a value at the given position', () {
      final matrix = Matrix.empty();
      final position = CellPosition(row: 1, column: 1);

      matrix.setValue(position, 7);
      expect(matrix.getValue(position), 7);

      matrix.clearValue(position);

      expect(matrix.getValue(position), isNull);
    });

    test('clearing an empty cell keeps it empty', () {
      final matrix = Matrix.empty();
      final position = CellPosition(row: 3, column: 3);

      matrix.clearValue(position);

      expect(matrix.getValue(position), isNull);
    });
  });

  group('Matrix bounds', () {
    test('throws when setting a value outside row bounds', () {
      final matrix = Matrix.empty();

      expect(
            () => matrix.setValue(CellPosition(row: -1, column: 0), 1),
        throwsA(isA<RangeError>()),
      );

      expect(
            () => matrix.setValue(CellPosition(row: 9, column: 0), 1),
        throwsA(isA<RangeError>()),
      );
    });

    test('throws when setting a value outside column bounds', () {
      final matrix = Matrix.empty();

      expect(
            () => matrix.setValue(CellPosition(row: 0, column: -1), 1),
        throwsA(isA<RangeError>()),
      );

      expect(
            () => matrix.setValue(CellPosition(row: 0, column: 9), 1),
        throwsA(isA<RangeError>()),
      );
    });

    test('throws when reading a value outside bounds', () {
      final matrix = Matrix.empty();

      expect(
            () => matrix.getValue(CellPosition(row: -1, column: 0)),
        throwsA(isA<RangeError>()),
      );

      expect(
            () => matrix.getValue(CellPosition(row: 0, column: 9)),
        throwsA(isA<RangeError>()),
      );
    });
  });

  group('Matrix value validation', () {
    test('accepts values between 1 and gridSize', () {
      final matrix = Matrix.empty(size: 9);

      for (var value = 1; value <= 9; value++) {
        final position = CellPosition(row: 0, column: value - 1);

        matrix.setValue(position, value);

        expect(matrix.getValue(position), value);
      }
    });

    test('throws when value is below valid range', () {
      final matrix = Matrix.empty();

      expect(
            () => matrix.setValue(CellPosition(row: 0, column: 0), 0),
        throwsA(anything),
      );
    });

    test('throws when value is above valid range', () {
      final matrix = Matrix.empty(size: 9);

      expect(
            () => matrix.setValue(CellPosition(row: 0, column: 0), 10),
        throwsA(anything),
      );
    });
  });

  group('Matrix copy behavior', () {
    test('copy creates an independent matrix', () {
      final original = Matrix.empty();
      final position = CellPosition(row: 0, column: 0);

      original.setValue(position, 3);

      final copy = Matrix.clone(original);

      expect(copy.gridSize, original.gridSize);
      expect(copy.getValue(position), 3);

      copy.setValue(position, 8);

      expect(copy.getValue(position), 8);
      expect(original.getValue(position), 3);
    });
  });

  group('Matrix equality', () {
    test('two empty matrices with the same size are equal', () {
      final first = Matrix.empty(size: 9);
      final second = Matrix.empty(size: 9);

      expect(first, equals(second));
    });

    test('matrices with different values are not equal', () {
      final first = Matrix.empty(size: 9);
      final second = Matrix.empty(size: 9);

      first.setValue(CellPosition(row: 0, column: 0), 1);
      second.setValue(CellPosition(row: 0, column: 0), 2);

      expect(first, isNot(equals(second)));
    });

    test('matrices with different sizes are not equal', () {
      final first = Matrix.empty(size: 4);
      final second = Matrix.empty(size: 9);

      expect(first, isNot(equals(second)));
    });
  });

  group('Matrix serialization', () {
    test('converts matrix to json and back', () {
      final matrix = Matrix.empty(size: 9);

      matrix.setValue(CellPosition(row: 0, column: 0), 1);
      matrix.setValue(CellPosition(row: 4, column: 4), 5);
      matrix.setValue(CellPosition(row: 8, column: 8), 9);

      final json = matrix.asJson();
      final restored = Matrix.fromJson(json);

      expect(restored?.gridSize, matrix.gridSize);
      expect(restored?.getValue(CellPosition(row: 0, column: 0)), 1);
      expect(restored?.getValue(CellPosition(row: 4, column: 4)), 5);
      expect(restored?.getValue(CellPosition(row: 8, column: 8)), 9);
      expect(restored, equals(matrix));
    });
  });
  group("Games Tests", () {
    test("JSON Encoding", () async {
      final games = Games();
      games.clear();
      games.newGame(name: "test");
      var m = (await games.current.first)?.matrix;
      m!.setValue(CellPosition(), 1);
      var encoded = games.asJson();
      var list = GamesModel
          .fromJson(encoded)
          .games;
      expect(list.length, 1);
      expect(list[0].name, "test");
    });
  });
}

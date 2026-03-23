
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
import 'dart:ui';

import 'package:sudoku/model.dart';

///
/// Represents one cell in the Sudoko Matrix.
///
class Cell {
  ///
  /// Whether this cells value was pre-defined for the original game.
  ///
  bool given = false;
  ///
  /// Whether this cell was solved as part of solving the Sudoku.
  ///
  bool solved = false;

  ///
  /// Can be assigned by the system to mark a cell, which was solved
  /// by the user was solved in a wrong way.
  ///
  bool get falselySolved => falseGuess != null;
  ///
  /// A possible false guess value entered by the player.
  ///
  int? falseGuess;

  ///
  /// Whether this cell contains a value causing a duplicate.
  ///
  bool hasError = false;
  ///
  /// Can be used, when solving the Sudoku manually to mark a cell as being solved - one
  /// is sure, the value is correct.
  ///
  bool markedAsFound = false;
  int? value;
  int? trying;
  List<int> alternatives = [];

  @override
  String toString() => "Cell $value";
}


///
/// Represents one Sudoku game matrix.
///
class Matrix {
  static const int defaultSize = 9;
  String? name;
  List<List<Cell>> cells = [];

  final List<VoidCallback> _notifiers = [];

  void onGameChanged(VoidCallback callback) {
    _notifiers.add(callback);
  }

  ///
  /// Invoked, when the definition of this game has changed.
  ///
  void _gameChanged() {
    for (final c in _notifiers) {
      c();
    }
  }


  ///
  /// The indices at which a block ends in column direction. Depends on
  /// the total size of the matrix.
  ///
  final List<int> blockColumnBreaks = [3,6];

  ///
  /// The indices at which a block ends in row direction. Depends on
  /// the total size of the matrix.
  ///
  final List<int> blockRowBreaks = [3,6];

  ///
  /// Used to bail out calculating difficult games using back-tracking.
  ///
  static int _stepsToSolveGame = 0;
  bool dirty = false;

  ///
  /// Fast lookup of cell placements.
  ///
  final Map<Cell, Point<int>> _placements = {};

  ///
  /// Returns the placement of a cell in our matrix in form of
  /// a point with y being the row and x being the column.
  ///
  Point<int> placementOf(Cell cell) {
    var result = _placements[cell];
    if (result == null) {
      for (var i = 0; i < cells.length; i++) {
        var row = cells[i];
        for (var j = 0; j < row.length; j++) {
          var p = Point(j, i);
          _placements[row[j]] = p;
          if (cell == row[j]) {
            result = p;
          }
        }
      }
    }
    return result ?? Point(-1,-1);
  }

  int get rowCount => cells.length;

  int get columnCount => cells.isEmpty ? 0 : cells[0].length;

  @override
  int get hashCode => cells.fold(0, (v, row1) => row1.fold(0, (a,b) => a+(b.value ?? 13)));

  @override
  bool operator== (Object other) {
    if (other is! Matrix) {
      return false;
    }
    if (cells.length != other.cells.length) {
      return false;
    }
    for (var i = 0; i < cells.length; i++) {
      var row1 = cells[i];
      var row2 = other.cells[i];
      if (row2.length != row1.length) {
        return false;
      }
      for (var j = 0; j < row1.length; j++) {
        if (row1[j].value != row2[j].value) {
          return false;
        }
      }
    }
    return true;
  }

  static Matrix? fromJson(Map<String, dynamic> json) {
    var name = json["name"];
    var cells = json["cells"];
    if (cells is String) {
      return Matrix.parse(cells)..name = name;
    }
    if (cells is! List) {
      return null;
    }
    var input = List<List<dynamic>>.from(cells);
    var result = Matrix.empty(size: input.length);
    result.name = name;
    result.place(input.map(List<int?>.from).toList());
    result.markGivenCells();
    return result;
  }

  static Matrix clone(Matrix m) {
    var result = Matrix.empty(size: m.gridCount, columnBreaks: m.blockColumnBreaks, rowBreaks: m.blockRowBreaks);
    result.cellsDo((cell, row, column) {
      var origin = m.cells[row][column];
      cell.value = origin.value;
      cell.solved = origin.solved;
      cell.given = origin.given;
      return true;
    });
    return result;
  }

  ///
  /// Eliminate values in the matrix using back-tracking
  ///
  Matrix? tryToEliminateValue(Matrix m, Matrix originalMatrix, Random rand, int numberOfEmptyPlaces, Point<int> p) {
    if (numberOfEmptyPlaces <= 0) {
      return m;
    }
    numberOfEmptyPlaces--;
    m = Matrix.clone(m);
    var nonEmptySlots = <Point<int>>[];
    m.cellsDo((cell, row, column) {
      if (cell.value != null) {
        nonEmptySlots.add(Point(column, row));
      }
      return true;
    });
    int retries = 0;
    // give up, if we did not succeed to generate a game after more than 5 retries to short-cut the recursive algorithm.
    while(nonEmptySlots.isNotEmpty && retries < 5) {
      p = nonEmptySlots[rand.nextInt(nonEmptySlots.length)];
      var val = m.valueAt(p.y, p.x);
      if (val == null) {
        throw Exception("Did not move to empty slot ${p.x} ${p.y}");
      }
      m.setValue(p.y, p.x, null);
      var tester = Matrix.clone(m);
      var solved = tester.solve();
      if (solved == originalMatrix) {
        var result = tryToEliminateValue(m, originalMatrix, rand, numberOfEmptyPlaces, p);
        if (result != null) {
          return result;
        }
      }
      m.setValue(p.y, p.x, val);
      nonEmptySlots.remove(p);
      retries++;
    }
    return null;
  }

  ///
  /// Generate a game matrix.
  ///
  Matrix? generateGame({required int numberOfEmptyPlaces}) {
    var m = generateValidMatrix();
    if (m == null) {
      return null;
    }
    var originalMatrix = Matrix.clone(m);
    var rand = Random.secure();
    m = tryToEliminateValue(m, originalMatrix, rand, numberOfEmptyPlaces, Point<int>(0,0));
    if (m == null) {
      return null;
    }
    m.cellsDo((cell, _, _) {
      cell.given = cell.value != null;
      cell.solved = false;
      return true;
    });
    return m;
  }

  ///
  /// Generate a new valid Sudoku Matrix.
  ///
  Matrix? generateValidMatrix() {
    if (solved) {
      return this;
    }
    if (!checkValid) {
      return null;
    }
    return autoPlaceNewValue(col: 0, row: 0);
  }

  bool _isEmpty(Cell cell, bool empty) => empty ? cell.value == null : cell.value != null;

  ({int row, int col})? findNextEmpty(int row, int col, {bool empty = true}) {
    while(row < gridCount) {
      while(col < gridCount) {
        if (_isEmpty(cells[row][col], empty)) {
          return (row: row, col: col);
        }
        col++;
      }
      if (col >= gridCount) {
        row++;
        col = 0;
      } else {
        break;
      }
    }
    return null;
  }

  Matrix? autoPlaceNewValue({Random? rand, required int col, required int row}) {
    var result = findNextEmpty(row, col);
    if (result == null) {
      return this;
    }
    rand ??= Random.secure();
    row = result.row;
    col = result.col;
    var cellRow = rowValues(row);
    var cellCol = colValues(col);
    var cellBlock = blockValues(row, col);
    var existing = cellRow.toSet();
    existing.addAll(cellCol);
    existing.addAll(cellBlock);
    if (existing.length == gridCount) {
      return null;
    }
    var avail = List.generate(gridCount, (index) => index+1);
    for (final v in existing) {
      avail.remove(v);
    }
    while(avail.isNotEmpty) {
      var idx = rand.nextInt(avail.length);
      cells[row][col].value = avail[idx];
      var m = Matrix.clone(this);
      var result = m.autoPlaceNewValue(col: col, row: row);
      if (result != null) {
        return result;
      }
      avail.removeAt(idx);
    }
    return null;
  }


  ///
  /// Parse a string defining a Sudoku game with empty cells containing a placeholder character such as X or _
  /// and with other cells defining the number all separated by spaces.
  ///
  /// Example string which can be parsed to a matrix:
  ///           "_ _ _ 8 3 _ _ _ _ "
  ///           "_ _ _ _ 7 4 _ 5 _ "
  ///           "_ _ _ _ _ _ _ _ _ "
  ///           "_ _ 4 _ _ 6 _ _ 8 "
  ///           "2 _ _ _ 8 _ _ _ 9 "
  ///           "_ 6 _ 1 _ 2 4 _ _ "
  ///           "_ _ 5 7 _ _ 9 _ 3 "
  ///           "9 8 _ _ _ _ _ _ 5 "
  ///           "_ _ 1 _ 6 5 _ _ 4 "
  ///
  Matrix.parse(String s, {int? size}) {
    var tokens = s.split(RegExp("\\s+"));
    size ??= sqrt(tokens.length).round();
    if (tokens.length < size*size) {
      throw Exception("Invalid number of tokens in matrix definition ${tokens.length}");
    }
    _addCells(size);
    for (int i = 0; i < size; i++) {
      for (int j = 0; j < size; j++) {
        int idx = i * size + j;
        var cell = tokens[idx];
        var value = (cell == '_' || cell == 'X') ? null : int.tryParse(cell);
        cells[i][j].value = value;
      }
    }
  }

  ///
  /// Mark a cell which was solved by the user the wrong way to mark it in the UI.
  ///
  void markFalselyManualSolvedCells(Matrix mWithManualSolution) {
    cellsDo((cell, row, col) {
      Cell other = mWithManualSolution.cells[row][col];
      if (!other.given && other.value != null && other.value != cell.value) {
        cell.falseGuess = other.value;
      }
      return true;
    });
  }

  ///
  /// Add a list of cells with a given [size].
  ///
  void _addCells(int size, {List<int>? columnBreaks, List<int>? rowBreaks}) {
    columnBreaks = defaultColumnBreaks[size] ?? [3,6];
    blockColumnBreaks.clear();
    blockColumnBreaks.addAll(columnBreaks);

    rowBreaks = defaultRowBreaks[size] ?? [3,6];
    blockRowBreaks.clear();
    blockRowBreaks.addAll(rowBreaks);
    for (var row = 0; row < size; row++) {
      var rowCells = List.generate(size, (index) => Cell());
      cells.add(rowCells);
    }
  }

  ///
  /// The default column break positions to use depending on the matrix size.
  ///
  static final Map<int, List<int>> defaultColumnBreaks = {
    25: [5, 10, 15, 20],
    12 : [4, 8],
    9 : [3,6],
    6 : [3]
  };

  ///
  /// The default row break positions to use depending on the matrix size.
  ///
  static final Map<int, List<int>> defaultRowBreaks = {
    25: [5, 10, 15, 20],
    9 : [3,6],
    12 : [3, 6, 9],
    6 : [2,4]
  };

  ///
  /// Generate an empty matrix with a default size of 9x9 or a given size.
  ///
  Matrix.empty({int? size, List<int>? columnBreaks, List<int>? rowBreaks}) {
    size ??= defaultSize;
    _addCells(size, columnBreaks: columnBreaks, rowBreaks: rowBreaks);
  }

  static Matrix from(List<dynamic> init, {String? name}) {
    var result = Matrix.empty(size: init.length);
    var list = init.map((l) => List<int?>.from(l)).toList();
    result.place(list);
    result.name = name;
    result.markGivenCells();
    return result;
  }

  ///
  /// Check whether 3 given cells have the same applicable triple of alternatives.
  ///
  List<int>? sharedTriples(Cell c1, Cell c2, Cell c3) {
    var joined = <int>{};
    joined.addAll(c1.alternatives);
    joined.addAll(c2.alternatives);
    joined.addAll(c3.alternatives);
    if (joined.length != 3) {
      return null;
    }
    return joined.toList();
  }

  ///
  /// Implements the naked triples strategy.
  ///
  /// Tries to find three identical naked triples for the given set of cells which together
  /// must conform to the rule, that every cell must have a distinct value. If such two cells can
  /// be identified, the two alternative values selectable for the two cells can be removed from
  /// the alternatives of all other cells in the given set of cells.
  ///
  void eliminateNakedTriples(List<Cell> cells) {
    Cell? first;
    Cell? second;
    Cell? third;
    var applicableCells = cells.where((c) => c.alternatives.length == 2 || c.alternatives.length == 3).toList();
    if (applicableCells.length < 3) {
      return;
    }
    for (int i = 0; i < applicableCells.length-2; i++) {
      first = applicableCells[i];
      for (int j = i+1; j < applicableCells.length; j++) {
        second = applicableCells[j];
        for (int k = j+1; k < applicableCells.length; k++) {
          third = applicableCells[k];
          var shared = sharedTriples(first, second, third);
          if (shared != null) {
            for (var i = 0; i < cells.length - 1; i++) {
              final cell = cells[i];
              if (cell != first && cell != second && cell != third) {
                cell.alternatives.removeWhere((a) => shared.contains(a));
              }
            }
          }
        }
      }
    }
  }

  ///
  /// Implements the naked pairs strategy.
  ///
  /// Tries to find two identical naked pairs for the given set of cells which together
  /// must conform to the rule, that every cell must have a distinct value. If such two cells can
  /// be identified, the two alternative values selectable for the two cells can be removed from
  /// the alternatives of all other cells in the given set of cells.
  ///
  void eliminateNakedPairs(List<Cell> cells) {
    Cell? first;
    Cell? second;
    for (var i = 0; i < cells.length-1; i++) {
      final cell = cells[i];
      if (cell.alternatives.length == 2) {
        for (int j = i+1; j < cells.length; j++) {
          final cell2 = cells[j];
          if (cell2.alternatives.length == 2) {
            var compare = cell2.alternatives.toSet();
            compare.removeAll(cell.alternatives);
            if (compare.isEmpty) {
              first = cell;
              second = cell2;
              break;
            }
          }
        }
        if (first != null && second != null) {
          break;
        }
      }
    }
    if (first != null) {
      for (var i = 0; i < cells.length-1; i++) {
        final cell = cells[i];
        if (cell != first && cell != second) {
          cell.alternatives.removeWhere((a) => first!.alternatives.contains(a));
        }
      }
    }
  }

  ///
  /// Detect hidden singles in a house of cells and eliminate the "non-singles" from
  /// the list of alternatives.
  ///
  void findHiddenSingles(List<Cell> cells) {
    for (var i = 1; i < gridCount; i++) {
      var matching = cells.where((c) => c.value == null && c.alternatives.contains(i));
      if (matching.length == 1) {
        matching.first.alternatives.removeWhere((v) => v != i);
      }
    }
  }

  ///
  /// Calculate the possible alternatives to be used for a cell.
  /// Return [true] if the matrix is solvable and [false] otherwise.
  ///
  void recalculateAlternatives() {
    var cValues = <Iterable<int>>[];
    for (var i = 0; i < gridCount; i++) {
      cValues.add(colValues(i));
    }
    var rValues = <Iterable<int>>[];
    for (var i = 0; i < gridCount; i++) {
      rValues.add(rowValues(i));
    }
    if (!cellsDo((cell, r, c) => _calculateAlternatives(r, c, rValues, cValues))) {
      return;
    }
    for (var i = 0; i < rowCount; i++) {
      var row = rowAt(i);
      findHiddenSingles(row);
      eliminateNakedPairs(row);
      eliminateNakedTriples(row);
    }
    for (var j = 0; j < columnCount; j++) {
      var column = columnAt(j);
      findHiddenSingles(column);
      eliminateNakedPairs(column);
      eliminateNakedTriples(column);
    }
    blocksDo((cells) {
      findHiddenSingles(cells);
      eliminateNakedPairs(cells);
      eliminateNakedTriples(cells);
      return true;
    });
  }

  void place(List<List<int?>> init) {
    cellsDo((cell, r, c) {
      setValue(r, c, init[r][c]);
      return true;
    });
    recalculateAlternatives();
  }

  int? valueAt(int row, int col) => cells[row][col].value;

  ///
  /// Assign [val] to the cell in [row] and [col].
  ///
  void setValue(int row, int col, int? val) {
    cells[row][col].value = val;
  }

  Map<String, dynamic> asJson() => {
    "name": name,
    "cells": cells
        .map((row) => row.map((cell) => cell.value).toList())
        .toList(),
  };

  void clearGuesses() {
    cellsDo((cell, r, c) {
      if (cell.solved) {
        cell.value = null;
        cell.solved = false;
        cell.alternatives.clear();
      }
      cell.hasError = false;
      cell.falseGuess = null;
      return true;
    });
  }

  Iterable<int> rowValues(int row) =>
      rowAt(row).map((c) => c.value).nonNulls;
  Iterable<int> colValues(int col) =>
      columnAt(col).map((c) => c.value).nonNulls;
  void blockCellsDo(int row, int col, void Function(Cell cell) callback) {
    var cells = blockCells(row, col);
    for (final cell in cells) {
      callback(cell);
    }
  }

  Iterable<Cell> blockCells(int row, int col) {
    var result = <Cell>[];
    int rowStart = 0;
    int rowEnd = blockRowBreaks[0];
    int columnStart = 0;
    int columnEnd = blockColumnBreaks[0];
    for (var rIdx = 0; rIdx < blockRowBreaks.length; rIdx++) {
      if (row >= blockRowBreaks[rIdx]) {
        rowStart = blockRowBreaks[rIdx];
        rowEnd = rIdx+1 >= blockRowBreaks.length ? gridCount : blockRowBreaks[rIdx+1];
      } else {
        break;
      }
    }
    for (var cIdx = 0; cIdx < blockColumnBreaks.length; cIdx++) {
      if (col >= blockColumnBreaks[cIdx]) {
        columnStart = blockColumnBreaks[cIdx];
        columnEnd = cIdx+1 >= blockColumnBreaks.length ? gridCount : blockColumnBreaks[cIdx+1];
      } else {
        break;
      }
    }
    for (int r = rowStart; r < rowEnd; r++) {
      for (int c = columnStart; c < columnEnd; c++) {
        result.add(cells[r][c]);
      }
    }
    return result;
  }

  ///
  /// Returns all values contained in a cell block 3x3.
  ///
  Iterable<int> blockValues(int row, int col) {
    var values = <int>{};
    blockCellsDo(row, col, (c) {
      if (c.value != null) {
        values.add(c.value!);
      }
    });
    return values;
  }

  ///
  /// Execute a callback [f] for each cell of our Sudoku game.
  /// If the callback returns false, execution completes.
  ///
  bool cellsDo(bool Function(Cell cell, int row, int column) f) {
    for (int r = 0; r < cells.length; r++) {
      for (int c = 0; c < cells[r].length; c++) {
        if (!f(cells[r][c], r, c)) {
          return false;
        }
      }
    }
    return true;
  }

  bool get solved {
    var solved = true;
    cellsDo((cell, r, c) {
      if (cell.value == null) {
        solved = false;
        return false;
      }
      return true;
    });
    return solved;
  }

  void blocksDo(bool Function(List<Cell> blockCells) callback) {
    var startRows = [0, ...blockRowBreaks];
    var startColumns = [0, ...blockColumnBreaks];
    for (int r = 0; r < startRows.length; r++) {
      for (int c = 0; c < startColumns.length; c++) {
        final cells = blockCells(startRows[r], startColumns[c]);
        if (!callback(cells.toList())) {
          return;
        }
      }
    }
  }

  bool get checkValid {
    cellsDo((cell, r, c) {
      cell.hasError = false;
      return true;
    });
    var valid = true;
    for (int r = 0; r < cells.length; r++) {
      var v = rowValues(r);
      var duplicates = v.toList().getDuplicates();
      if (duplicates.isNotEmpty) {
        valid = false;
        for (final cell in cells[r]) {
          if (duplicates.contains(cell.value)) {
            cell.hasError = true;
          }
        }
      }
    }
    for (int c = 0; c < cells[0].length; c++) {
      var v = colValues(c);
      var duplicates = v.toList().getDuplicates();
      if (duplicates.isNotEmpty) {
        valid = false;
        for (final cell in cells.map((cells) => cells[c])) {
          if (duplicates.contains(cell.value)) {
            cell.hasError = true;
          }
        }
      }
    }
    blocksDo((blockCells) {
      var duplicates = blockCells.where((cell) => cell.value != null).map((cell) => cell.value).getDuplicates();
      if (duplicates.isNotEmpty) {
        valid = false;
        for (final cell in blockCells) {
          if (duplicates.contains(cell.value)) {
            cell.hasError = true;
          }
        }
      }
      return true;
    });
    return valid;
  }

  ///
  /// Return [false] if the cell cannot be solved any more.
  ///
  bool _calculateAlternatives(int row, int col, List<Iterable<int>> rowValues, List<Iterable<int>> colValues) {
    var cell = cells[row][col];
    if (cell.value != null) {
      cell.alternatives = [];
      return true;
    }
    var selected = <int>{
      ...rowValues[row],
      ...colValues[col],
      ...blockValues(row, col),
    };
    final a = List<int>.generate(gridCount, (index) => index + 1).toSet();
    a.removeAll(selected);
    if (a.isEmpty) {
      return false;
    }
    cell.alternatives = a.toList();
    return true;
  }

  ///
  /// Returns a row of cells. [rowNumber] must lay within the size of the matrix
  ///
  List<Cell> rowAt(int rowNumber) => cells[rowNumber];

  ///
  /// For Fast access of the grid column cells.
  ///
  final List<List<Cell>> _columns = [];

  ///
  /// Returns a column of cells. [columnNumber] must lay within the size of the matrix
  ///
  List<Cell> columnAt(int columnNumber) {
    if (_columns.isEmpty) {
      for (int i = 0; i < gridCount; i++) {
        var list = cells.map((l) => l[i]).toList();
        _columns.add(list);
      }
    }
    return _columns[columnNumber];
  }

  ///
  /// Tries to find rows / columns / a block of cells where only one cell is not resolved - in
  /// that case fill in the last missing value.
  ///
  bool addLastValueToGroup(List<Cell> cells) {
    var empty = cells.where((c) => c.value == null);
    if (empty.length == 1) {
      var values = cells.map((c) => c.value);
      var candidate = empty.first;
      for (int i = 1; i <= rowCount; i++) {
        if (!values.contains(i)) {
          candidate.value = i;
          candidate.solved = true;
          break;
        }
      }
      return true;
    }
    return false;
  }

  void cellResolved(Cell cell, int row, int column) {
    cell.alternatives.remove(cell.value);
    var colCells = columnAt(column);
    for (final cell in colCells) {
      cell.alternatives.remove(cell.value);
    }
    var rowCells = rowAt(column);
    for (final cell in rowCells) {
      cell.alternatives.remove(cell.value);
    }
    var cells = blockCells(row, column);
    for (final cell in cells) {
      cell.alternatives.remove(cell.value);
    }
  }

  ///
  /// Answers true, if the matrix is solvable at all. Before calling this method you must call recalculateAlternatives().
  ///
  bool get solvable => cells.expand((l) => l).where((c) => c.value == null && c.alternatives.isEmpty).isEmpty;

  ///
  /// Resolve the obvious cases of a Sudoko game before entering expensive back-tracking.
  /// Return false if the matrix is not solvable.
  ///
  bool resolveDeterministicCases() {
    bool resolved = true;
    recalculateAlternatives();
    if (!solvable) {
      return false;
    }
    while (resolved) {
      resolved = false;
      var rowColBlockResolved = false;
      cellsDo((cell, row, column) {
        if (cell.alternatives.length == 1) {
          cell.value = cell.alternatives.first;
          cell.solved = true;
          resolved = true;
          cellResolved(cell, row, column);
        }
        return true;
      });
      for (int i = 0; i < rowCount; i++) {
        var list = rowAt(i);
        if (addLastValueToGroup(list)) {
          resolved = true;
          rowColBlockResolved = true;
        }
      }
      for (int i = 0; i < columnCount; i++) {
        var list = columnAt(i);
        if (addLastValueToGroup(list)) {
          resolved = true;
          rowColBlockResolved = true;
        }
      }
      blocksDo((cells) {
        if (addLastValueToGroup(cells)) {
          resolved = true;
          rowColBlockResolved = true;
        }
        return true;
      });
      if (rowColBlockResolved) {
        recalculateAlternatives();
      }
    }
    return solvable;
  }

  Matrix? tryNextAlternative({required int row, required int column}) {
    var originalCell = cells[row][column];
    var tryNext = originalCell.trying;
    if (originalCell.alternatives.isEmpty) {
      return null;
    }
    if (tryNext == null || tryNext < originalCell.alternatives.length - 1) {
      tryNext = tryNext == null ? 0 : tryNext + 1;
      cells[row][column].trying = tryNext;
      var copy = Matrix.clone(this);
      var cell = copy.cells[row][column];
      cell.value = originalCell.alternatives[tryNext];
      cell.solved = true;
      return copy;
    }
    return null;
  }

  ({int row, int column})? get nextCellWithAlternatives {
    var l = 1000;
    ({int row, int column})? candidate;
    for (int r = 0; r < cells.length; r++) {
      for (int c = 0; c < cells[r].length; c++) {
        var cell = cells[r][c];
        if (cell.value != null || cell.alternatives.length < 2) {
          continue;
        }
        var nAlternatives = cell.alternatives.length;
        if (nAlternatives < l) {
          l = nAlternatives;
          candidate = (row: r, column: c);
        }
      }
    }
    return candidate;
  }

  ///
  /// The size of the Sudoku Grid used - typically 9.
  ///
  int get gridCount => cells.length;

  ///
  /// Answer true if a matrix is empty.
  ///
  bool get isEmpty => !cells.any((r) => r.any((c) => c.value != null));

  ///
  /// Return a number identifying the difficulty to solve this matrix. This is currently
  /// calculated based on the number of empty cells compared to the grid count and on the
  /// number of possible alternatives still possible for each cell also in comparison to the grid
  /// count.
  ///
  int get difficultyLevel {
    var m = Matrix.clone(this);
    m.clearGuesses();
    m.recalculateAlternatives();
    var nEmpty = m.emptyCells.length;
    var nAlternatives = m.allCells.fold(0, (a,c) => a+c.alternatives.length);
    return nEmpty * 3 ~/ gridCount + (nAlternatives / 2 ~/gridCount);
  }

  Iterable<Cell> get allCells => cells.expand((l) => l);

  ///
  /// Returns all "empty cells", where no value has been placed yet.
  ///
  Iterable<Cell> get emptyCells => allCells.where((c) => c.value == null && c.given);

  ///
  /// Returns the number of values (occupied places) in the matrix.
  ///
  int get valueCount {
    var occupied = 0;
    cellsDo((c, _, _) {
      if (c.value != null) {
        occupied++;
      }
      return true;
    });
    return occupied;
  }

  ///
  /// Solve a Sudoku game using back-tracking. Pretty trivial algorithm with few optimizations.
  ///
  Matrix? solve() {
    _stepsToSolveGame = 0;
    return _solve(0);
  }

  bool get bailedOut => _stepsToSolveGame > 100;

  ///
  /// The input filter restricting the input which can be types by the user
  /// into the text field of the cells.
  ///
  RegExp get inputFilter => gridCount < 10 ? RegExp('[1-$gridCount]') : gridCount < 20 ? RegExp('(1[0-${gridCount-10}])|([1-9])') :
    RegExp('([12][0-$gridCount])|([1-$gridCount])');

  ///
  /// Solve a Sudoku game using back-tracking. Pretty trivial algorithm with few optimizations.
  ///
  Matrix? _solve([int level = 0]) {
    if (!resolveDeterministicCases()) {
      return null;
    }
    if (!checkValid || !solvable) {
      return null;
    }
    if (bailedOut) {
      Games.logger.w("Bailing out while solving a game after $_stepsToSolveGame iterations.");
      return null;
    }
    if (solved) {
      return this;
    }
    var cellPos = nextCellWithAlternatives;
    if (cellPos == null) {
      return null;
    }
    Matrix? m;
    while ((m = tryNextAlternative(row: cellPos.row, column: cellPos.column)) != null) {
      _stepsToSolveGame++;
      var done = m!._solve(level + 1);
      if (done != null) {
        done.name = name;
        return done;
      }
      if (bailedOut) {
        return null;
      }
    }
    return null;
  }

  ///
  /// Use this method to update the number of a Sudoku cell, when the user edits the Sudoku matrix.
  /// If [creatingGame] is true, the cell is edited of part of manually creating a new game.
  ///
  void editCellValue(Cell c, String? s, bool creatingGame) {
    var newValue = int.tryParse(s ?? "");
    if (newValue == c.value) {
      return;
    }
    c.value = newValue;
    c.solved = false;
    c.given = creatingGame && newValue != null;
    dirty = true;
    _gameChanged();
  }

  ///
  /// Mark all cells with a value as `given` - they are expected to
  /// be defined as part of the game played.
  ///
  void markGivenCells() {
    cellsDo((c, _, _) {
      c.given = c.value != null;
      return true;
    });
  }

  void toggleCellFoundMarker(Cell cell) {
    if (!cell.hasError && !cell.given) {
      cell.markedAsFound = !cell.markedAsFound;
    }
  }

  bool isCellEditable(int column, int row, bool creatingGame) {
    var c = cells[row][column];
    return c.given ? creatingGame : !c.given;
  }

  void clearEdits() {
    cellsDo((c,_,_) {
      if (!c.given) {
        c.solved = false;
        c.value = null;
      }
      return true;
    });
  }

  String debugPrint() =>
      cells.map((row) => row.map((c) => "${c.value ?? 'x'} ").join("")).join("\n");

}

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:logger/logger.dart';

extension ListExtension<T> on List<T> {
  List<T> getDuplicates() =>
      where((x) => where((y) => x == y).length > 1).toList();
}

///
/// Represents one cell in the Sudoko Matrix.
///
class Cell {
  bool solved = false;
  bool hasError = false;
  int? value;
  int? trying;
  List<int> alternatives = [];

  @override
  String toString() => "Cell $value";
}

///
/// The games defined in our Sudoku application.
///
class Games {
  static Logger logger = Logger(
    printer: PrettyPrinter(stackTraceBeginIndex: 10000),
  );
  Games._() {
    initialize();
  }
  static final Games _singleton = Games._();
  static final Matrix sample = Matrix.from([
    [null, 3, null, null, null, null, null, null, null],
    [null, null, null, 1, 9, 5, null, null, null],
    [null, null, 8, null, null, null, null, 6, null],
    [8, null, null, null, 6, null, null, null, null],
    [4, null, null, 8, null, null, null, null, 1],
    [null, null, null, null, 2, null, null, null, null],
    [null, 6, null, null, null, null, 2, 8, null],
    [null, null, null, 4, 1, 9, null, null, 5],
    [null, null, null, null, null, null, null, 7, null],
  ]);
  factory Games() => _singleton;
  final String historyFile = "sudoku.json";
  final List<Matrix> games = [];
  Matrix current = sample;
  int get numberOfGames => games.length;

  void addGame(Matrix matrix) {
    if (games.contains(matrix)) {
      return;
    }
    matrix.name ??= "Game ${DateTime.now().toIso8601String()}";
    games.removeWhere(((g) => g.name == matrix.name));
    games.add(matrix);
  }

  void initialize() {
    readHistory();
    addGame(sample);
    current = games.last;
  }

  String asJson() {
    final output = {"games": games.map((g) => g.asJson()).toList()};
    return jsonEncode(output);
  }

  void save() {
    logger.i("Saving list of current games to file $historyFile");
    final file = File(historyFile);
    file.writeAsStringSync(asJson());
    for (final g in games) {
      g.dirty = false;
    }
  }

  List<Matrix> decodeGames(String gamesEncodedAsJson) {
    final contents = jsonDecode(gamesEncodedAsJson);
    final games = contents["games"];
    final result = <Matrix>[];
    if (games is List) {
      for (final g in games) {
        result.add(Matrix.from(g["cells"], name: g["name"]));
      }
    }
    return result;
  }

  void readHistory() {
    final file = File(historyFile);
    if (!file.existsSync()) {
      logger.i("No history file found");
      return;
    }
    var games = decodeGames(file.readAsStringSync());
    logger.i("Reading history file ${file.absolute.path} with ${games.length} saved games.");
    for (final matrix in games) {
      addGame(matrix);
    }
  }

  ///
  /// Create a new game and add it to the list of games.
  ///
  void newGame({String? name}) {
    var m = Matrix.empty();
    m.name = name;
    addGame(m);
    current = m;
  }

  ///
  /// Clear the list of saved games
  ///
  void clear() {
    games.clear();
  }

  ///
  /// Load a game given its name. A game with the given name must exist or
  /// an exception is thrown.
  ///
  void load(String name) {
    var m = games.where((g) => g.name == name).firstOrNull;
    if (m != null && m != current) {
      m.clearGuesses();
      current = m;
    }
  }

  void useSample() {
    current = sample;
  }

  void markDirty(bool value) {
    for (final game in games) {
      game.dirty = value;
    }
  }
}

///
/// Represents one Sudoku game state.
///
class Matrix {
  static const int defaultSize = 9;
  String? name;
  List<List<Cell>> cells = [];
  static int _maxLevelToSolve = 0;
  bool dirty = false;

  ///
  /// Returns the placement of a cell in our matrix in form of
  /// a point with y being the row and x being the column.
  ///
  Point<int> placementOf(Cell cell) {
    for (var i = 0; i < cells.length; i++) {
      var row = cells[i];
      for (var j = 0; j < row.length; j++) {
        if (cell == row[j]) {
          return Point(j, i);
        }
      }
    }
    return Point(-1,-1);
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
    if (cells is! List) {
      return null;
    }
    var input = List<List<int>>.from(cells);
    var result = Matrix.empty();
    result.name = name;
    result.place(input);
    return result;
  }

  static Matrix clone(Matrix m) {
    var result = Matrix.empty();
    result.cellsDo((cell, row, column) {
      var origin = m.cells[row][column];
      cell.value = origin.value;
      cell.solved = origin.solved;
    });
    return result;
  }

  Matrix.parse(String s, {int? size}) {
    size ??= defaultSize;
    _addCells(size);
    for (int i = 0; i < defaultSize; i++) {
      for (int j = 0; j < defaultSize; j++) {
        int idx = i * defaultSize * 2 + (j*2);
        if (idx >= s.length) {
          throw Exception("Specified matrix string is not big enough");
        }
        var cell = s.substring(idx, idx+1);
        var value = cell == '_' ? null : int.tryParse(cell);
        cells[i][j].value = value;
      }
    }
  }

  void _addCells(int size) {
    for (var row = 0; row < size; row++) {
      var rowCells = List.generate(size, (index) => Cell());
      cells.add(rowCells);
    }
  }

  Matrix.empty({int? size}) {
    size ??= defaultSize;
    _addCells(size);
  }

  static Matrix from(List<dynamic> init, {String? name}) {
    var result = Matrix.empty();
    var list = init.map((l) => List<int?>.from(l)).toList();
    result.place(list);
    result.name = name;
    return result;
  }

  void recalculateAlternatives() {
    cellsDo((cell, r, c) => calculateAlternatives(r, c));
  }

  void place(List<List<int?>> init) {
    cellsDo((cell, r, c) {
      setValue(r, c, init[r][c]);
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
        cell.hasError = false;
        cell.alternatives.clear();
      }
    });
  }

  List<int> rowValues(int row) =>
      cells[row].map((c) => c.value).nonNulls.toList();
  List<int> colValues(int col) =>
      cells.map((c) => c[col]).map((c) => c.value).nonNulls.toList();
  List<Cell> blockCells(int row, int col) {
    var result = <Cell>[];
    for (int r = row ~/ 3 * 3; r < row ~/ 3 * 3 + 3; r++) {
      for (int c = col ~/ 3 * 3; c < col ~/ 3 * 3 + 3; c++) {
        result.add(cells[r][c]);
      }
    }
    return result;
  }

  List<int> blockValues(int row, int col) =>
      blockCells(row, col).map((c) => c.value).nonNulls.toList();

  void cellsDo(void Function(Cell cell, int row, int column) f) {
    for (int r = 0; r < cells.length; r++) {
      for (int c = 0; c < cells[r].length; c++) {
        f(cells[r][c], r, c);
      }
    }
  }

  bool get solved {
    var solved = true;
    cellsDo((cell, r, c) {
      solved = solved && cell.value != null;
    });
    return solved;
  }

  bool get checkValid {
    cellsDo((cell, r, c) {
      cell.hasError = false;
    });
    var valid = true;
    for (int r = 0; r < cells.length; r++) {
      var v = rowValues(r);
      var duplicates = v.getDuplicates();
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
      var duplicates = v.getDuplicates();
      if (duplicates.isNotEmpty) {
        valid = false;
        for (final cell in cells.map((cells) => cells[c])) {
          if (duplicates.contains(cell.value)) {
            cell.hasError = true;
          }
        }
      }
    }
    for (int r = 0; r < cells.length; r += 3) {
      for (int c = 0; c < cells[0].length; c += 3) {
        var v = blockValues(r, c);
        var duplicates = v.getDuplicates();
        if (duplicates.isNotEmpty) {
          valid = false;
          for (final cell in blockCells(r, c)) {
            if (duplicates.contains(cell.value)) {
              cell.hasError = true;
            }
          }
        }
      }
    }
    return valid;
  }

  void calculateAlternatives(int row, int col) {
    if (cells[row][col].value != null) {
      cells[row][col].alternatives = [];
      return;
    }
    var selected = [
      ...rowValues(row),
      ...colValues(col),
      ...blockValues(row, col),
    ];
    final a = List<int>.generate(9, (index) => index + 1).toSet();
    a.removeAll(selected);
    cells[row][col].alternatives = a.toList();
  }

  ///
  /// Returns a row of cells. [rowNumber] must lay within the size of the matrix
  ///
  List<Cell> rowAt(int rowNumber) => cells[rowNumber];
  ///
  /// Returns a column of cells. [columnNumber] must lay within the size of the matrix
  ///
  List<Cell> columnAt(int columnNumber) => cells.map((l) => l[columnNumber]).toList();

  ///
  /// Tries to find rows / columns where only one cell is not resolved.
  ///
  bool resolveLine(List<Cell> cells) {
    Cell? candidate;
    List<int> values = cells.where((c) => c.value != null).map((c) => c.value!).toList();
    if (values.length == rowCount-1) {
      candidate = cells.firstWhere((c) => c.value == null);
      for (int i = 1; i <= rowCount; i++) {
        if (!values.contains(i)) {
          candidate.value = i;
          break;
        }
      }
      return true;
    }
    return false;
  }

  ///
  /// Resolve the obvious cases of a Sudoko game before entering expensive back-tracking.
  ///
  void resolveDeterministicCases() {
    bool resolved = true;
    while (resolved) {
      resolved = false;
      cellsDo((cell, _, _) {
        if (cell.alternatives.length == 1) {
          cell.value = cell.alternatives.first;
          cell.solved = true;
          resolved = true;
        }
      });
      for (int i = 0; i < rowCount; i++) {
        var list = rowAt(i);
        if (resolveLine(list)) {
          resolved = true;
        }
      }
      for (int i = 0; i < columnCount; i++) {
        var list = columnAt(i);
        if (resolveLine(list)) {
          resolved = true;
        }
      }

      recalculateAlternatives();
    }
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
        if (cell.value != null) {
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

  int get difficultyLevel {
    _maxLevelToSolve = 0;
    var m = Matrix.clone(this);
    m.clearGuesses();
    m.solve();
    int level = _maxLevelToSolve;
    return level;
  }

  ///
  /// Solve a Sudoku game using back-tracking. Pretty trivial algorithm with few optimizations.
  ///
  Matrix? solve([int level = 0]) {
    resolveDeterministicCases();
    if (solved) {
      return this;
    }
    if (!checkValid) {
      return null;
    }
    if (level > _maxLevelToSolve) {
      _maxLevelToSolve = level;
    }
    var cellPos = nextCellWithAlternatives;
    if (cellPos == null) {
      return null;
    }
    while (checkValid) {
      var m = tryNextAlternative(row: cellPos.row, column: cellPos.column);
      if (m == null) {
        return null;
      }
      var done = m.solve(level + 1);
      if (done != null) {
        done.name = name;
        return done;
      }
    }
    return null;
  }

  ///
  /// Use this method to update the number of a Sudoku cell, when the user edits the Sudoku matrix.
  ///
  void editCellValue(Cell c, String? s) {
    var newValue = int.tryParse(s ?? "");
    if (newValue != c.value) {
      return;
    }
    c.value = newValue;
    dirty = true;
  }
}

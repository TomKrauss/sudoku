
import 'dart:convert';
import 'dart:io';

extension ListExtension<T> on List<T> {
  List<T> getDuplicates() => where((x) => where((y) => x == y).length > 1).toList();
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
/// The games defined in our little application.
///
class Games {
  Games._() {
    initialize();
  }
  static final Games _singleton = Games._();
  factory Games() => _singleton;
  final String historyFile = "sudoku.json";
  final List<Matrix> games = [];

  void addGame(Matrix matrix) {
    matrix.name ??= "Game ${games.length+1}";
    games.removeWhere(((g) => g.name == matrix.name));
    games.add(matrix);
  }

  void initialize() {
    addGame(Matrix.from([
      [null, 3, null, null, null, null, null, null, null],
      [null, null, null, 1, 9, 5, null, null, null],
      [null, null, 8, null, null, null, null, 6, null],
      [ 8, null, null, null, 6, null, null, null, null],
      [ 4, null, null, 8, null, null, null, null, 1],
      [null, null, null, null, 2, null, null, null, null],
      [null, 6, null, null, null, null, 2, 8, null],
      [null, null, null, 4, 1, 9, null, null, 5],
      [null, null, null, null, null, null, null, 7, null],
    ]));
    readHistory();
  }

  void save() {
    final output = {
      "games": games.map((g) => g.asJson()).toList()
    };
    final file = File(historyFile);
    file.writeAsStringSync(jsonEncode(output));
  }

  void readHistory() {
    final file = File(historyFile);
    if (!file.existsSync()) {
      return;
    }
    final contents = jsonDecode(file.readAsStringSync());
    final games = contents["games"];
    if (games is List) {
      for (final g in games) {
        addGame(Matrix.from(g));
      }
    }
  }
}

///
/// Represents one Sudoku game state.
///
class Matrix {
  String? name;
  List<List<Cell>> cells = [];

  int get rowCount => cells.length;

  static Matrix? fromJson(Map<String,dynamic> json) {
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

  Matrix.empty() {
    for (var row = 0; row < 9; row++) {
      var rowCells = List.generate(9, (index) => Cell());
      cells.add(rowCells);
    }
  }

  static Matrix from(List<List<int?>> init, {String? name}) {
    var result = Matrix.empty();
    result.place(init);
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

  void setValue(int row, int col, int? val) => cells[row][col].value = val;

  Map<String, dynamic> asJson() => {
    "name": name,
    "cells": cells.map((row) => row.map((cell) => cell.value))
  };

  void clearGuesses() {
    cellsDo((cell, r, c) {
      if (cell.solved) {
        cell.value = null;
        cell.solved = false;
      }
    });
  }
  List<int> rowValues(int row) => cells[row].map((c) => c.value).nonNulls.toList();
  List<int> colValues(int col) => cells.map((c) => c[col]).map((c) => c.value).nonNulls.toList();
  List<Cell> blockCells(int row, int col) {
    var result = <Cell>[];
    for (int r = row ~/ 3 * 3; r < row ~/ 3 * 3 + 3; r++) {
      for (int c = col ~/ 3 * 3; c < col ~/ 3 * 3 + 3; c++) {
        result.add(cells[r][c]);
      }
    }
    return result;
  }

  List<int> blockValues(int row, int col) => blockCells(row, col).map((c) => c.value).nonNulls.toList();

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
    for (int r = 0; r < cells.length; r+=3) {
      for (int c = 0; c < cells[0].length; c+=3) {
        var v = blockValues(r, c);
        var duplicates = v.getDuplicates();
        if (duplicates.isNotEmpty) {
          valid = false;
          for (final cell in blockCells(r,c)) {
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
    var selected = [...rowValues(row), ...colValues(col), ...blockValues(row, col)];
    final a = List<int>.generate(9, (index) => index+1).toSet();
    a.removeAll(selected);
    cells[row][col].alternatives = a.toList();
  }

  ///
  /// Resolve the obvious cases of a Sudoko game before entering expensive back-tracking.
  ///
  void resolveDeterministicCases() {
    bool resolved = true;
    while(resolved) {
      resolved = false;
      cellsDo((cell, _, _) {
        if (cell.alternatives.length == 1) {
          cell.value = cell.alternatives.first;
          cell.solved = true;
          resolved = true;
        }
      });
      recalculateAlternatives();
    }
  }

  Matrix? tryNextAlternative({required int row, required int column}) {
    var originalCell = cells[row][column];
    var tryNext = originalCell.trying;
    if (originalCell.alternatives.isEmpty) {
      return null;
    }
    if (tryNext == null || tryNext < originalCell.alternatives.length-1) {
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
    var cellPos = nextCellWithAlternatives;
    if (cellPos == null) {
      return null;
    }
    while(checkValid) {
      var m = tryNextAlternative(row: cellPos.row, column: cellPos.column);
      if (m == null) {
        return null;
      }
      var done = m.solve(level+1);
      if (done != null) {
        return done;
      }
    }
    return null;
  }
}

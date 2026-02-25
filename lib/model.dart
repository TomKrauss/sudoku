import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

extension ListExtension<T> on List<T> {
  List<T> getDuplicates() =>
      where((x) => where((y) => x == y).length > 1).toList();
}

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

enum GameMode {
  playing,
  creating,
  solved
}

///
/// Represents one Sudoku game. This can have several modes / states:
/// - in play mode one can try to solve the game manually
/// - in creation mode one can manually edit and add new games.
/// - in solved mode the app calculates and displays a solved version of the game.
///
class Game {
  final Matrix matrix;
  GameMode _mode = GameMode.playing;
  Matrix? _playingMatrix;
  Matrix? _solvedMatrix;

  String? get name => matrix.name;
  set name(String? n) => matrix.name = n;

  set dirty(bool dirty) => matrix.dirty = dirty;
  bool get dirty => matrix.dirty;

  set gameMode(GameMode mode) {
    if (_mode != mode) {
      _mode = mode;
      onChanged();
    }
  }

  void onChanged() {
    var matrix = current;
    if (matrix == null) {
      return;
    }
    matrix.recalculateAlternatives();
    matrix.checkValid;
  }

  Matrix? get current {
    switch (gameMode) {
      case GameMode.playing: return playingMatrix;
      case GameMode.creating: return matrix;
      default: return solvedMatrix;
    }
  }
  Matrix get playingMatrix {
    _playingMatrix ??= Matrix.clone(matrix);
    return _playingMatrix!;
  }

  Matrix? get solvedMatrix {
    if (_solvedMatrix == null) {
      _solvedMatrix = Matrix.clone(matrix);
      _solvedMatrix = _solvedMatrix?.solve();
    }
    return _solvedMatrix;
  }

  Game(this.matrix);

  @override
  int get hashCode => matrix.hashCode;

  bool get isEmpty => matrix.isEmpty;

  GameMode get gameMode => _mode;

  int get columnCount => matrix.columnCount;
  int get rowCount => matrix.rowCount;

  int get gridCount => matrix.gridCount;

  List<List<Cell>> get cells => currentNotNull.cells;

  @override
  bool operator ==(Object other) => other is Game && matrix == other.matrix;

  Map<String,dynamic> asJson() => matrix.asJson();

  Matrix get currentNotNull => current ?? matrix;

  int get difficultyLevel => matrix.difficultyLevel;

  bool isCellEditable(int x, int y) => current?.isCellEditable(x, y, gameMode == GameMode.creating) ?? false;

  void editCellValue(Cell c, String? s) {
    currentNotNull.editCellValue(c, s, gameMode == GameMode.creating);
  }

  Point<int> placementOf(Cell cell) => currentNotNull.placementOf(cell);

  void toggleCellFoundMarker(Cell cell) {
    if (gameMode == GameMode.playing) {
      currentNotNull.toggleCellFoundMarker(cell);
    }
  }
}

///
/// The games defined in our Sudoku application.
///
class Games {
  static Logger logger = Logger(
    printer: PrettyPrinter(stackTraceBeginIndex: 10000),
  );
  Games._() {
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
  static String historyFile = "";

  Future<void> _initializePath() async {
    var file = historyFile;
    if (file.isNotEmpty) {
      return;
    }
    var name = "sudoku.json";
    if (File(name).existsSync()) {
      historyFile = name;
      return;
    }
    name = join((await getApplicationDocumentsDirectory()).absolute.path, name);
    historyFile = name;
  }

  final List<Game> games = [];
  Game current = Game(sample);

  int get numberOfGames => games.length;

  void addGame(Game game) {
    if (games.contains(game)) {
      return;
    }
    game.name ??= "Game ${DateTime.now().toIso8601String()}";
    games.removeWhere(((g) => g.name == game.name));
    games.add(game);
  }

  Future<bool> initialize() async {
    await _initializePath();
    readHistory();
    addGame(Game(sample));
    current = games.last;
    return true;
  }

  String asJson() {
    final output = {"games": games.map((g) => g.asJson()).toList()};
    var encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(output);
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
      logger.i("No history file found. Was looking in ${file.absolute.path}");
      return;
    }
    var games = decodeGames(file.readAsStringSync());
    logger.i("Reading history file ${file.absolute.path} with ${games.length} saved games.");
    for (final game in games) {
      addGame(Game(game));
    }
  }

  ///
  /// Create a new game and add it to the list of games.
  ///
  void newGame({String? name}) {
    var m = Matrix.empty();
    m.name = name;
    var game = Game(m);
    addGame(game);
    current = game;
    game.gameMode = GameMode.creating;
  }

  ///
  /// Clear the list of saved games
  ///
  void clear() {
    games.clear();
  }

  ///
  /// Select a game given its name and mae it the current game. A game with the given name must exist or
  /// an exception is thrown.
  ///
  void selectGameNamed(String name) {
    var m = games.where((g) => g.name == name).firstOrNull;
    if (m != null && m != current) {
      current = m;
    }
  }

  void useSample() {
    current = Game(sample);
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
  ///
  /// Used to calculate the difficulty of a game.
  ///
  static int _stepsToSolveGame = 0;
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
    result.markGivenCells();
    return result;
  }

  static Matrix clone(Matrix m) {
    var result = Matrix.empty();
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
    size ??= defaultSize;
    _addCells(size);
    var tokens = s.split(RegExp("\\s+"));
    for (int i = 0; i < defaultSize; i++) {
      for (int j = 0; j < defaultSize; j++) {
        int idx = i * defaultSize + j;
        var cell = tokens[idx];
        var value = (cell == '_' || cell == 'X') ? null : int.tryParse(cell);
        cells[i][j].value = value;
      }
    }
  }

  ///
  /// Add a list of cells with a given [size].
  ///
  void _addCells(int size) {
    for (var row = 0; row < size; row++) {
      var rowCells = List.generate(size, (index) => Cell());
      cells.add(rowCells);
    }
  }

  ///
  /// Generate an empty matrix with a default size of 9x9 or a given size.
  ///
  Matrix.empty({int? size}) {
    size ??= defaultSize;
    _addCells(size);
  }

  static Matrix from(List<dynamic> init, {String? name}) {
    var result = Matrix.empty();
    var list = init.map((l) => List<int?>.from(l)).toList();
    result.place(list);
    result.name = name;
    result.markGivenCells();
    return result;
  }

  ///
  /// Tries to find two identical alternative pairs for the given set of cells which together
  /// must conform to the rule, that every cell must have a distinct value. If such two cells can
  /// be identified, the two alternative values selectable for the two cells can be removed from
  /// the alternatives of all other cells in the given set of cells.
  ///
  void eliminateAlternativePairs(List<Cell> cells) {
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
  /// Calculate the possible alternatives to be used for a cell.
  ///
  void recalculateAlternatives() {
    cellsDo((cell, r, c) => calculateAlternatives(r, c));
    for (var i = 0; i < rowCount; i++) {
      var row = cells[i];
      eliminateAlternativePairs(row);
      for (var j = 0; j < columnCount; j++) {
        var column = columnAt(j);
        eliminateAlternativePairs(column);
      }
    }
    blocksDo((cells) {
      eliminateAlternativePairs(cells);
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
        cell.hasError = false;
        cell.alternatives.clear();
      }
      return true;
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

  ///
  /// Returns all values contained in a cell block 3x3.
  ///
  List<int> blockValues(int row, int col) =>
      blockCells(row, col).map((c) => c.value).nonNulls.toList();

  ///
  /// Execute a callback [f] for each cell of our Sudoku game.
  /// If the callback returns false, execution completes.
  ///
  void cellsDo(bool Function(Cell cell, int row, int column) f) {
    for (int r = 0; r < cells.length; r++) {
      for (int c = 0; c < cells[r].length; c++) {
        if (!f(cells[r][c], r, c)) {
          break;
        }
      }
    }
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
    for (int r = 0; r < cells.length; r += 3) {
      for (int c = 0; c < cells[0].length; c += 3) {
        final cells = blockCells(r, c);
        if (!callback(cells)) {
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

  bool calculateAlternatives(int row, int col) {
    if (cells[row][col].value != null) {
      cells[row][col].alternatives = [];
      return true;
    }
    var selected = <int>{
      ...rowValues(row),
      ...colValues(col),
      ...blockValues(row, col),
    };
    final a = List<int>.generate(9, (index) => index + 1).toSet();
    a.removeAll(selected);
    cells[row][col].alternatives = a.toList();
    return true;
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
  /// Tries to find rows / columns / a block of cells where only one cell is not resolved - in
  /// that case fill in the last missing value.
  ///
  bool addLastValueToGroup(List<Cell> cells) {
    Cell? candidate;
    List<int> values = cells.where((c) => c.value != null).map((c) => c.value!).toList();
    if (values.length == rowCount-1) {
      candidate = cells.firstWhere((c) => c.value == null);
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
        return true;
      });
      for (int i = 0; i < rowCount; i++) {
        var list = rowAt(i);
        if (addLastValueToGroup(list)) {
          resolved = true;
        }
      }
      for (int i = 0; i < columnCount; i++) {
        var list = columnAt(i);
        if (addLastValueToGroup(list)) {
          resolved = true;
        }
      }
      blocksDo((cells) {
        if (addLastValueToGroup(cells)) {
          resolved = true;
        }
        return true;
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
    _stepsToSolveGame = 0;
    var m = Matrix.clone(this);
    m.clearGuesses();
    m.solve();
    return _stepsToSolveGame;
  }

  ///
  /// Solve a Sudoku game using back-tracking. Pretty trivial algorithm with few optimizations.
  ///
  Matrix? solve([int level = 0]) {
    resolveDeterministicCases();
    if (!checkValid) {
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
      var done = m!.solve(level + 1);
      _stepsToSolveGame++;
      if (done != null) {
        done.name = name;
        return done;
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
    c.given = creatingGame;
    dirty = true;
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
}

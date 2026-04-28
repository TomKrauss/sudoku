// The MIT License (MIT)
//
// Copyright © 2026 <copyright holders>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sudoku/matrix.dart';

///
/// An input formatter controlling the value which can be typed into a Sudoku cell.
/// Only numeric input is supported so far.
///
class SudokuInputFormatter extends TextInputFormatter {
  ///
  /// The maximum number allowed by the grid (typically 9).
  ///
  final int maxNumber;
  SudokuInputFormatter({required this.maxNumber});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    if (newValue.text.startsWith("0")) {
      return oldValue;
    }
    var n = int.tryParse(newValue.text);
    if (n == null || n < 1 || n > maxNumber) {
      return oldValue;
    }
    return newValue;
  }

}
///
/// Utility to get the duplicate elements in a list.
///
extension ListExtension<T> on Iterable<T> {
  Iterable<T> getDuplicates() =>
      where((x) => where((y) => x == y).toList().length > 1);
}

///
/// The mode in which the game is operated.
///
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
  static final List<String> sampleGames = [/*"sudoku_easy.txt", "sudoku_hard.txt", "sudoku_medium.txt",*/ "sudoku_super160.txt"];
  static final String sampleDirectory = "lib/assets/sample_games";
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
      if (mode == GameMode.solved) {
        calculateSolvedMatrix();
      }
      onChanged();
    }
  }

  void onChanged() {
    var matrix = current;
    if (matrix == null) {
      return;
    }
    matrix.recalculateAlternatives(breakOnError: false);
    if (_playingMatrix != null && _playingMatrix != matrix) {
      matrix.markFalselyManualSolvedCells(_playingMatrix!);
    }
    matrix.checkValid;
  }

  Matrix? get current {
    switch (gameMode) {
      case GameMode.playing:
        return playingMatrix;
      case GameMode.creating:
        return matrix;
      default:
        return solvedMatrix;
    }
  }

  Matrix get playingMatrix {
    _playingMatrix ??= Matrix.clone(matrix);
    return _playingMatrix!;
  }

  ///
  /// Calculate the solved matrix, if that had not been yet calculated
  /// or if it must be recalculated.
  ///
  void calculateSolvedMatrix() {
    if (_solvedMatrix == null) {
      _solvedMatrix = Matrix.clone(matrix);
      _solvedMatrix = _solvedMatrix?.solve();
    }
  }

  Matrix? get solvedMatrix => _solvedMatrix;

  Game(this.matrix) {
    matrix.onGameChanged(() {
      // need to recalculate the solved matrix.
      _solvedMatrix = null;
    });
  }

  @override
  int get hashCode => matrix.hashCode;

  bool get isEmpty => matrix.isEmpty;

  GameMode get gameMode => _mode;

  int get columnCount => matrix.columnCount;

  int get rowCount => matrix.rowCount;

  int get gridCount => matrix.gridSize;

  List<List<Cell>> get cells => currentNotNull.cells;

  @override
  bool operator ==(Object other) => other is Game && matrix == other.matrix;

  Map<String, dynamic> asJson() => matrix.asJson();

  Matrix get currentNotNull => current ?? matrix;

  int get difficultyMetrics => matrix.difficultyMetrics;
  int get difficulty => currentNotNull.difficulty;

  ///
  /// The input filter restricting the input which can be types by the user
  /// into the text field of the cells.
  ///
  TextInputFormatter get inputFilter => SudokuInputFormatter(maxNumber: gridCount);

  bool isCellEditable(CellPosition p) =>
      current?.isCellEditable(p, gameMode == GameMode.creating) ?? false;

  void editCellValue(Cell c, String? s) {
    var creating = gameMode == GameMode.creating;
    var matrix = currentNotNull;
    matrix.editCellValue(c, s, creating);
    if (creating && matrix != _playingMatrix && _playingMatrix != null) {
      var p = matrix.placementOf(c);
      var c2 = _playingMatrix!.getCell(p);
      _playingMatrix!.editCellValue(c2, s, true);
    }
  }

  CellPosition placementOf(Cell cell) => currentNotNull.placementOf(cell);

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
  Games._();

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
  final Set<String> _gameNames = {};
  Stream<Game?> get current => _streamController.stream;
  final StreamController<Game?> _streamController = BehaviorSubject.seeded(Game(sample));

  int get numberOfGames => games.length;
  static bool _operationRunning = false;

  void addGame(Game game) {
    if (game.name != null && games.contains(game)) {
      return;
    }
    if (game.name == null) {
      var s = "Game #${games.length + 1}";
      while(_gameNames.contains(s)) {
        s += "_";
      }
      game.name = s;
    } else {
      games.removeWhere(((g) => g.name == game.name));
    }
    games.add(game);
    _gameNames.add(game.name!);
  }

  ///
  /// Generate a new game with the given name and size. Size defaults to 9.
  /// By changing the number of empty places to reserve, one can generate
  /// simple or more complex to solve games. If size is not 9, the numberOfEmptyPlaces
  /// is normalized to a Sudoko with size 9.
  ///
  Future<void> generateGame({int? level, int? numberOfEmptyPlaces, String? name, int? size}) async {
    if (_operationRunning) {
      return;
    }
    _operationRunning = true;
    try {
      _streamController.add(null);
      Matrix? m = Matrix.empty(size: size);
      // give the UI a chance to repaint.
      m = await Isolate.run<Matrix?>(() =>
          m!.generateGame(numberOfEmptyPlaces:
              numberOfEmptyPlaces ??= m.numberOfEmptyPlacesForLevel(level ?? 1)));
      if (m != null) {
        var g = Game(m);
        if (name != null) {
          g.name = name;
        }
        addGame(g);
        _streamController.add(g);
      } else {
        await selectGameNamed(games.first.name ?? "");
      }
    } finally {
      _operationRunning = false;
    }
  }

  Future<bool> initialize() async {
    await _initializePath();
    readHistory();
    await readSampleGames();
    addGame(Game(sample));
    _streamController.add(games.last);
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

  List<Matrix> decodeGamesFromJson(String gamesEncodedAsJson) {
    final contents = jsonDecode(gamesEncodedAsJson);
    final games = contents["games"];
    final result = <Matrix>[];
    if (games is List) {
      for (final g in games) {
        var m = Matrix.fromJson(g);
        if (m != null) {
          result.add(m);
        }
      }
    }
    return result;
  }

  List<Matrix> decodeGamesFromText(String gamesEncodedAsTxt) {
    final result = <Matrix>[];
    for (final g in gamesEncodedAsTxt.split(Platform.lineTerminator)) {
      if (g.isEmpty || g.startsWith("# ")) {
        continue;
      }
      var m = Matrix.parse(g);
      result.add(m);
    }
    return result;
  }

  void importFileOrAsset(String string, String fileName, {int? maxGamesPerFile, String? Function(int index)? generateName}) {
    var games = extension(fileName) == '.txt' ? decodeGamesFromText(string) : decodeGamesFromJson(string);
    logger.i("Reading file $fileName with ${maxGamesPerFile ?? games.length} saved games.");
    var idx = 1;
    for (final game in games) {
      if (game.name == null && generateName != null) {
        game.name = generateName(idx);
      }
      addGame(Game(game));
      idx++;
      if (maxGamesPerFile != null && idx >= maxGamesPerFile) {
        break;
      }
    }
  }

  ///
  /// Import multiple games from a Sudoku format input file located in the assets folder. Several formats are supported - simple
  /// txt format with each line containing a sudoku game or JSON formats.
  ///
  Future<void> loadGamesFromAsset(String fileName, {int? maxGamesPerFile}) async {
    try {
      var buffer = await rootBundle.load(fileName);
      var string = maxGamesPerFile != null && buffer.buffer.lengthInBytes > 100 * maxGamesPerFile ?
          utf8.decode(Uint8List.sublistView(buffer, 100 * maxGamesPerFile)) : utf8.decode(Uint8List.sublistView(buffer));
      importFileOrAsset(string, fileName, maxGamesPerFile: maxGamesPerFile, generateName: (idx) => "${withoutExtension(basename(fileName))}, Game  #$idx");
    } catch(ex) {
      logger.i("No asset named $fileName found: $ex");
    }
  }

  ///
  /// Import multiple games from a Sudoku format input file. Several formats are supported - simple
  /// txt format with each line containing a sudoku game or JSON formats.
  ///
  void importGamesFromFile(String fileName, {int? maxGamesPerFile}) {
    final file = File(fileName);
    if (!file.existsSync()) {
      logger.i("No file named $fileName found. Was looking in ${file.absolute.path}");
      return;
    }
    var string = file.readAsStringSync();
    importFileOrAsset(string, file.absolute.path, maxGamesPerFile: maxGamesPerFile);
  }

  void readHistory() {
    importGamesFromFile(historyFile);
  }

  Future<void> readSampleGames() async {
    for (final f in Game.sampleGames) {
      await loadGamesFromAsset("${Game.sampleDirectory}/$f", maxGamesPerFile: 100);
    }
  }

  ///
  /// Create a new game and add it to the list of games.
  ///
  void newGame({String? name, int? size}) {
    var m = Matrix.empty(size: size);
    m.name = name;
    var game = Game(m);
    addGame(game);
    game.gameMode = GameMode.creating;
    _streamController.add(game);
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
  Future<Game?> selectGameNamed(String name) async {
    var m = games.where((g) => g.name == name).firstOrNull;
    if (m != null && m != await current.first) {
      _streamController.add(m);
      return m;
    }
    return null;
  }

  void useSample() {
    _streamController.add(Game(sample));
  }

  void markDirty(bool value) {
    for (final game in games) {
      game.dirty = value;
    }
  }

}


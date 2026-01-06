import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sudoku/grid_paper.dart';
import 'package:sudoku/model.dart';

double cellSize = 50;

///
/// Display one cell in the Sudoku board.
///
class CellWidget extends StatelessWidget {
  const CellWidget(this.cell, this.onChanged, {super.key});
  final Cell cell;
  final Function(String? newVal)? onChanged;

  Widget get editWidget => TextField(
    decoration: InputDecoration(border: InputBorder.none),
    textAlign: TextAlign.center,
    controller: TextEditingController(text: "${cell.value ?? ''}"), onChanged: onChanged,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly], keyboardType: TextInputType.number,);

  Widget get contentWidget => cell.value == null ? (Wrap(children: cell.alternatives.map((i) => Text(" $i ", style: TextStyle(fontSize: 10),)).toList(),)) :
      Text("${cell.value}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cell.hasError ? Colors.red : (cell.solved ? Colors.blue : Colors.black)),);

  @override
  Widget build(BuildContext context) => Container(
    width: cellSize,
    height: cellSize,
    alignment: Alignment.center,
    child: onChanged != null ? editWidget : contentWidget);
}

///
/// Main Entry Point into the Sudoku Application
///
void main() {
  runApp(const SudokuApplication());
}

///
/// A widget displaying the Sudoko Application.
///
class SudokuApplication extends StatelessWidget {
  const SudokuApplication({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku Solver',
      debugShowCheckedModeBanner: false,
      home: const SudokuBoard(title: 'Edit a Sudoku and solve it'),
    );
  }
}

///
/// A widget displaying a Sudoku Board.
///
class SudokuBoard extends StatefulWidget {
  const SudokuBoard({super.key, required this.title});
  final String title;

  @override
  State<SudokuBoard> createState() => _SudokuBoardState();
}

class _SudokuBoardState extends State<SudokuBoard> {
  Matrix m = sampleMatrix();
  bool editing = false;

  static Matrix sampleMatrix() => Games().games.first;

  @override
  void initState() {
    super.initState();
    Games().readHistory();
  }

  void initWithSample() {
    setState(() {
      m = sampleMatrix();
      editing = false;
    });
  }

  void clear() {
    setState(() {
      m = Matrix.empty();
      editing = true;
    });
  }

  void edit() {
    setState(() {
      if (editing) {
        m.clearGuesses();
        m.recalculateAlternatives();
        m.checkValid;
        editing = false;
      } else {
        m.clearGuesses();
        editing = true;
      }
    });
  }

  void solve() {
    setState(() {
      editing = false;
      var solved = m.solve();
      if (solved != null) {
        m = solved;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No resolution found.")));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(child: CustomGridPaper(divisions: 3, subdivisions: 3, interval: m.gridCount*cellSize, color: Colors.black, child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: m.cells.map((l) => Row(mainAxisSize: MainAxisSize.min, children: l.map((c) => CellWidget(c, editing ? (s) {
            c.value = int.tryParse(s??"");
          } : null)).toList(),)).toList(),
        ),
      )),
      bottomNavigationBar: BottomAppBar(child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        ElevatedButton(onPressed: solve, child: Text("Solve")),
        ElevatedButton(onPressed: clear, child: Text("Clear")),
        ElevatedButton(onPressed: edit, child: Text("Edit")),
        ElevatedButton(onPressed: initWithSample, child: Text("Sample"))],),),
    );
  }
}

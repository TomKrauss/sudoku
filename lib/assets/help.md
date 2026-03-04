# Sudoku 

## Introduction

Supports editing and solving Sudoku puzzles.

## How to use

- `Edit` - will allow you to enter a Sudoku puzzle manually.
- `Play` - will allow you to solve a Sudoku puzzle manually.
- `Select Game...` - will allow you to select a Sudoku puzzle from a list of pre-defined puzzles. pre-defined puzzles are stored in the
  file `sudoku.json`.
- `Save` - will allow for saving the current list of known puzzles in a file `sudoku.json`. When the application starts next time, it picks up the games stored here.
- `Show Solution` - will display the solution to the current puzzle. You may use `Clear Hints` then to remove the solution.
- `New Game...` - will allow you to start a new game. You may enter a name of the puzzle created now and fill out the pre-defined puzzle cell values. 
- `Generate Game...` - will allow you to generate a new game. You may select the difficulty level of the puzzle to generate.

### Working with the Sudoku Board
- When solving a puzzle, you may mark cells with a circle to indicate that you know the value of the cell. You can do so by double-clicking on the cell
or by pressing `Enter` on the cell.
- To navigate between cells, use the arrow keys.


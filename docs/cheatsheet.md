<img src='http://abe33.github.io/atom-tablr/heading.svg' width='858' height='50'>

## General

Command|Action
---|---
`core:save`|<p>OSX: <kbd>cmd-s</kbd><br/>Win/Linux: <kbd>ctrl-s</kbd></p>Save the current csv file using the provided initial setup.
`core:save-as`|<p>OSX: <kbd>cmd-shift-s</kbd><br/>Win/Linux: <kbd>ctrl-shift-s</kbd></p>Save the current csv file using the provided initial setup at the specified path.
`core:undo`|<p>OSX: <kbd>cmd-z</kbd><br/>Win/Linux: <kbd>ctrl-z</kbd></p>Undo the last change in the table.
`core:redo`|<p>OSX: <kbd>cmd-y</kbd><br/>Win/Linux: <kbd>ctrl-y</kbd></p>Redo the last change in the table.
`core:copy`|<p>OSX: <kbd>cmd-c</kbd><br/>Win/Linux: <kbd>ctrl-c</kbd></p>Copy the current selection in the clipboard.
`core:cut`|<p>OSX: <kbd>cmd-c</kbd><br/>Win/Linux: <kbd>ctrl-c</kbd></p>Copy the current selection in the clipboard and deletes the value of the selected cells.
`core:paste`|<p>OSX: <kbd>cmd-c</kbd><br/>Win/Linux: <kbd>ctrl-c</kbd></p>Copy the current selection in the clipboard.

## Cursors

Command|Action
---|---
`core:move-left`|<p>OSX/Win/Linux: <kbd>left</kbd></p>Move the cursors one cell to the left. If a selection spans several cells it sees its range reset to the new cursor position.<br/>If the current cell is a cell on the first column, the cursor will move on the last cell of the previous row.<br/>If the cell is the first cell of the first row, the cursor moves to the last table cell.
`core:move-right`|<p>OSX/Win/Linux: <kbd>right</kbd></p>Move the cursors one cell to the right. If a selection spans several cells it sees its range reset to the new cursor position.<br/>If the current cell is a cell on the last column, the cursor will move on the first cell of the next row.<br/>If the cell is the last cell of the last row, the cursor moves to the first table cell.
`core:move-up`|<p>OSX/Win/Linux: <kbd>up</kbd></p>Move the cursors one cell to the top. If a selection spans several cells it sees its range reset to the new cursor position.<br/>When the cursor is on the first row of the table it moves to the same column on the last row.
`core:move-down`|<p>OSX/Win/Linux: <kbd>down</kbd></p>Move the cursors one cell to the bottom. If a selection spans several cells it sees its range reset to the new cursor position.<br/>When the cursor is on the last row of the table it moves to the same column on the first row.
`tablr:move-left-in-selection`|<p>OSX/Win/Linux: <kbd>tab</kbd></p>Move the cursors one cell to the left inside its current selection. This is effective only if the selection spans many cells, otherwise this command behaves as `core:move-left`.
`tablr:move-right-in-selection`|<p>OSX/Win/Linux: <kbd>shift-tab</kbd></p>Move the cursors one cell to the right inside its current selection. This is effective only if the selection spans many cells, otherwise this command behaves as `core:move-right`.
`tablr:move-up-in-selection`|Move the cursors one cell to the top inside its current selection. This is effective only if the selection spans many cells, otherwise this command behaves as `core:move-up`.
`tablr:move-down-in-selection`|Move the cursors one cell to the bottom inside its current selection. This is effective only if the selection spans many cells, otherwise this command behaves as `core:move-down`.
`tablr:move-to-beginning-of-line`|<p>OSX: <kbd>cmd-left</kbd><br/>Win/Linux: <kbd>ctrl-left</kbd></p>Move the cursors to the first cell of the current row.
`tablr:move-to-end-of-line`|<p>OSX: <kbd>cmd-right</kbd><br/>Win/Linux: <kbd>ctrl-right</kbd></p>Move the cursors to the last cell of the current row.
`core:move-to-top`|<p>OSX: <kbd>cmd-up</kbd> <kbd>home</kbd><br/>Win/Linux: <kbd>ctrl-up</kbd> <kbd>home</kbd></p>Move the cursors to the first row of the table.
`core:move-to-bottom`|<p>OSX: <kbd>cmd-down</kbd> <kbd>end</kbd><br/>Win/Linux: <kbd>ctrl-down</kbd> <kbd>end</kbd></p>Move the cursor to the last row of the table.
`tablr:page-left`|Move the cursors left by the amount of rows specified in the `tablr.tableEditor.pageMoveColumnAmount` setting. <br/>The cursor will stop at the first column when going past the bounds.
`tablr:page-right`|Move the cursors right by the amount of rows specified in the `tablr.tableEditor.pageMoveColumnAmount` setting. <br/>The cursor will stop at the last column when going past the bounds.
`core:page-up`|<p>OSX/Win/Linux: <kbd>pageup</kbd></p>Move the cursors up by the amount of rows specified in the `tablr.tableEditor.pageMoveRowAmount` setting. <br/>The cursor will stop at the first row when going past the bounds.
`core:page-down`|<p>OSX/Win/Linux: <kbd>pagedown</kbd></p>Move the cursors down by the amount of rows specified in the `tablr.tableEditor.pageMoveRowAmount` setting. <br/>The cursor will stop at the last row when going past the bounds.
`tablr:add-selection-left`|Add a new cursor on the left of the last selection bounds and on the same row as the selection's cursor.
`tablr:add-selection-right`|Add a new cursor on the right of the last selection bounds and on the same row as the selection's cursor.
`tablr:add-selection-above`|<p>OSX: <kbd>ctrl-shift-up</kbd><br/>Win/Linux: <kbd>ctrl-alt-up</kbd></p>Add a new cursor above the last selection bounds and on the same column as the selection's cursor.
`tablr:add-selection-below`|<p>OSX: <kbd>ctrl-shift-down</kbd><br/>Win/Linux: <kbd>ctrl-alt-down</kbd></p>Add a new cursor below the last selection bounds and on the same column as the selection's cursor.
`tablr:go-to-line`|<p>OSX/Win/Linux: <kbd>ctrl-g</kbd></p>Jump to the specified row and column.

## Selections

Command|Action
---|---
`core:cancel`|<p>OSX/Win/Linux: <kbd>escape</kbd></p>Remove all selections except the last one.
`core:select-left`|<p>OSX/Win/Linux: <kbd>shift-left</kbd></p>Expand the selections by one cell to the left when the selection is expanded on the left of the cursor or shrink the selection by one cell when it's expanded on the right.
`core:select-right`|<p>OSX/Win/Linux: <kbd>shift-right</kbd></p>Expand the selections by one cell to the right when the selection is expanded on the right of the cursor or shrink the selection by one cell when it's expanded on the left.
`core:select-up`|<p>OSX/Win/Linux: <kbd>shift-up</kbd></p>Expand the selections by one cell to the top when the selection is expanded on the top of the cursor or shrink the selection by one cell when it's expanded on the bottom.
`core:select-down`|<p>OSX/Win/Linux: <kbd>shift-down</kbd></p>Expand the selections by one cell to the bottom when the selection is expanded on the bottom of the cursor or shrink the selection by one cell when it's expanded on the top.
`tablr:select-to-beginning-of-line`|<p>OSX: <kbd>cmd-shift-left</kbd><br/>Win/Linux: <kbd>ctrl-shift-left</kbd></p>Expand the selections to the first cell of each rows.
`tablr:select-to-end-of-line`|<p>OSX: <kbd>cmd-shift-right</kbd><br/>Win/Linux: <kbd>ctrl-shift-right</kbd></p>Expand the selections to the last cell of each rows.
`tablr:select-to-beginning-of-table`|<p>OSX: <kbd>cmd-shift-up</kbd><br/>Win/Linux: <kbd>ctrl-shift-up</kbd></p>Expand the selection to the first row of the table.
`tablr:select-to-end-of-table`|<p>OSX: <kbd>cmd-shift-down</kbd><br/>Win/Linux: <kbd>ctrl-shift-down</kbd></p>Expand the selection to the last row of the table.

## Edit

All these shortcuts applies when there is no edit session going on.

Command|Action
---|---
`core:confirm`|<p>OSX/Win/Linux: <kbd>enter</kbd></p>Start an edit session for every cursors.
`core:backspace`|<p>OSX/Win/Linux: <kbd>backspace</kbd></p>Delete the value of the currently selected cells.
`tablr:insert-row-before`|<p>OSX: <kbd>cmd-alt-n up</kbd><br/>Win/Linux: <kbd>ctrl-alt-n up</kbd></p>Insert a new empty row before the last cursor's row.
`tablr:insert-row-after`|<p>OSX: <kbd>cmd-alt-n down</kbd><br/>Win/Linux: <kbd>ctrl-alt-n down</kbd></p>Insert a new empty row after the last cursor's row.
`tablr:insert-column-before`|<p>OSX: <kbd>cmd-alt-n left</kbd><br/>Win/Linux: <kbd>ctrl-alt-n left</kbd></p>Insert a new empty column before the last cursor's column.
`tablr:insert-column-after`|<p>OSX: <kbd>cmd-alt-n right</kbd><br/>Win/Linux: <kbd>ctrl-alt-n right</kbd></p>Insert a new empty column after the last cursor's column.
`tablr:delete-row`|<p>OSX: <kbd>cmd-alt-backspace left</kbd> <kbd>cmd-alt-backspace right</kbd><br/>Win/Linux: <kbd>ctrl-alt-backspace left</kbd> <kbd>ctrl-alt-backspace right</kbd></p>Delete the row at the last cursor's position.
`tablr:delete-column`|<p>OSX: <kbd>cmd-alt-backspace up</kbd> <kbd>cmd-alt-backspace down</kbd><br/>Win/Linux: <kbd>ctrl-alt-backspace up</kbd> <kbd>ctrl-alt-backspace down</kbd></p>Delete the column at the last cursor's position.
`tablr:align-left`|Change the alignment of the column at the last cursor's position to `left`.
`tablr:align-center`|Change the alignment of the column at the last cursor's position to `center`.
`tablr:align-right`|Change the alignment of the column at the last cursor's position to `right`.
`tablr:expand-column`|<p>OSX/Win/Linux: <kbd>ctrl-alt-right</kbd></p>Increase the width of each column with a cursor by the amount specified in the `columnWidthIncrement` setting.
`tablr:shrink-column`|<p>OSX/Win/Linux: <kbd>ctrl-alt-left</kbd></p>Decrease the width of each column with a cursor by the amount specified in the `columnWidthIncrement` setting.
`tablr:expand-row`|<p>OSX/Win/Linux: <kbd>ctrl-alt-right</kbd></p>Increase the height of each row with a cursor by the amount specified in the `rowHeightIncrement` setting.
`tablr:shrink-row`|<p>OSX/Win/Linux: <kbd>ctrl-alt-left</kbd></p>Decrease the height of each row with a cursor by the amount specified in the `rowHeightIncrement` setting.
`tablr:move-line-up`|<p>OSX: <kbd>ctrl-cmd-up</kbd> <br/>Win/Linux: <kbd>ctrl-up</kbd></p>Move the lines at cursors one row to the top. This command is not available when an order is defined for the table as the result will not be perceived.
`tablr:move-line-down`|<p>OSX: <kbd>ctrl-cmd-down</kbd> <br/>Win/Linux: <kbd>ctrl-down</kbd></p>Move the lines at cursors one row to the bottom. This command is not available when an order is defined for the table as the result will not be perceived.
`tablr:move-column-left`|<p>OSX: <kbd>ctrl-cmd-left</kbd> <br/>Win/Linux: <kbd>ctrl-alt-left</kbd></p>Move the columns at cursors one column to the left.
`tablr:move-column-right`|<p>OSX: <kbd>ctrl-cmd-right</kbd> <br/>Win/Linux: <kbd>ctrl-alt-right</kbd></p>Move the columns at cursors one column to the right.
`tablr:apply-sort`|Applies the current sorting to the table so that the order can be saved on disk.
`tablr:fit-column-to-content`|Adjust the width of the column at the last cursor to the width of the widest cell's content.
`tablr:fit-row-to-content`|Adjust the height of the row at the last cursor to the height of the tallest cell's content.


## Cell Edit

Also, when an edit session is started, and the focus is in the `TextEditor`, the following keybindings are defined.

Command|Action
---|---
`core:confirm`|<p>OSX/Win/Linux: <kbd>enter</kbd></p>Confirm the edit and changes the value of all cells at cursor positions.
`core:cancel`|<p>OSX/Win/Linux: <kbd>escape</kbd></p>Abort the edit and leaves all the cells at cursor positions unchanged.
`tablr:move-right-in-selection`|<p>OSX/Win/Linux: <kbd>tab</kbd></p>Confirm the edit and move cursors one cell to the left in their respective selections.
`tablr:move-left-in-selection`|<p>OSX/Win/Linux: <kbd>shift-tab</kbd></p>Confirm the edit and move cursors one cell to the right in their respective selections.
`editor:newline`|<p>OSX: <kbd>cmd-enter</kbd> <kbd>ctrl-enter</kbd><br/>Win/Linux: <kbd>ctrl-enter</kbd></p> As the <kbd>enter</kbd> key is used to confirm the edit, alternative keybindings are necessary to insert new lines in a cell.
`editor:indent`|<p>OSX/Win/Linux: <kbd>ctrl-tab</kbd></p>As the <kbd>tab</kbd> key is already used to confirm the edit and move the cursors an alternative keybinding is necessary to insert a tabulation in a cell.

## Other

Command|Context|Action
---|---|---
`tablr:clear-csv-choice`|`atom-workspace`|Removes any choice remembered when opening a CSV file.
`tablr:clear-csv-layout`|`atom-workspace`|Removes any layout data stored for previously opened csv files.
`tablr:clear-csv-storage`|`atom-workspace`|Removes any data stored for previously opened csv files. It includes both choices and layouts.

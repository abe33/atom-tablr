<img src='http://abe33.github.io/atom-tablr/heading.svg' width='858' height='50'>

## Models Service

Tablr exposes its models through a [service](https://atom.io/docs/v1.0.16/behind-atom-interacting-with-other-packages-via-services) you can access by declaring a consumer in your `package.json` file:

```json
"consumedServices": {
  "tablr-models": {
    "versions": {
      "1.0.0": "consumeTablrModelsServiceV1"
    }
  }
}
```

```js
exports default {
  // ...
  consumeTablrModelsServiceV1: (api) => {
    let {Table, DisplayTable, Editor, Range} = api;

    // ...
  }
}
```

The following classes are exposed by the service:

Class|Role|
---|---|
`Table`|The `Table` model is the lowest level in Tablr hierarchy. Its main purpose is to handle the raw data: the columns and the rows that constitute a table. It also provides basic mechanisms to save the model on disk when provided with a save handler (more on that below). Lastly it handles the `modified` state of the table and provides the undo/redo mechanism. It's the equivalent of the `TextBuffer` class in Atom.
`DisplayTable`|The `DisplayTable` model handles the display state of a `Table` object, like the size of rows and columns, the sort to apply to the table rows and the alignment to use for each column. It's the equivalent of the `DisplayBuffer` class in Atom.
`TableEditor`|The `TableEditor` model is the upper model in the hierarchy, it composes a `DisplayTable` and provides the controls necessary to modify it. It stores the cursors and selections the user can manipulate and handles the copy/paste operation. It's the equivalent of the `TextEditor` class in Atom.
`Range`|When manipulating a table you can use the Atom's `Point` class, but ranges in a table are expressed differently than in a text editor. This model mimic the `Range` class from Atom but adjusted to the table specificities.

## Creating And Using A TableEditor

Let's pretend we want to use a `TableEditor` to edit a dummy file format. For the sake of keeping the example simple we'll also pretend to have a method that takes the file path as argument and return the data in an array of arrays with the column names in the first row.

What we need to do, once we got the data, is to create a `TableEditor` and fill it with the retrieved data.

```js
readFile(filePath, data => {
  let tableEditor = new TableEditor();

  tableEditor.lockModifiedStatus();

  tableEditor.addColumns(data.shift());
  tableEditor.addRows(data);

  tableEditor.initializeAfterSetup();
  tableEditor.unlockModifiedStatus();
});
```

In this example we have created a table editor, locked its modified state, added the table content and finalized the table setup by calling the `initializeAfterSetup` method and unlock the modified state.

By calling the two methods `lockModifiedStatus` and `unlockModifiedStatus` we make sure that all the operations we'll do on the table won't emit a `did-change-modified` event.

By calling `initializeAfterSetup` we drop the history created when filling the table and mark the table in as not modified.

At the end of the function we have a `TableEditor` that can be displayed in Atom by adding it into a panel. But at this point we cannot save the file yet.

### Save Handler

A save handler is just a function that will be called whenever the user triggers the `core:save` command in a table editor.

The save handler receive the underlying `Table` model that need to be saved and can either return a boolean or a `Promise`.

When returning a boolean, `true` means the save have been performed properly and `false` means the file couldn't be saved. When returning a `Promise`, if the promise resolves the save have been successful, a rejection, on the other hand, means the file couldn't be saved. If the file can't be saved the table will stay in a modified state.

Again, to keep the example simple, we'll pretend to have a method that writes on disk an array of arrays with the column names in the first row and call back a function when done.

```js
function save (table) {
  return new Promise((resolve, reject) =>
    let data = table.getRows();
    data.unshift(table.getColumns());

    writeFile(filePath, data, err => {
      if (err) {
        reject(err);
      }
      else {
        resolve();
      }
    });
  );
};
```

And now we can register the save handler on the table editor:

```js
readFile(filePath, data => {
  let tableEditor = new TableEditor();

  tableEditor.lockModifiedStatus();

  tableEditor.addColumns(data.shift());
  tableEditor.addRows(data);

  tableEditor.setSaveHandler(save);

  tableEditor.initializeAfterSetup();
  tableEditor.unlockModifiedStatus();
});
```

Now our table editor can be modified and saved on disk at any time.

If you want to see a more concrete example, you can take a look to the [CSVEditor class](https://github.com/abe33/atom-tablr/blob/master/lib/csv-editor.coffee) and [its test suite](https://github.com/abe33/atom-tablr/blob/master/spec/csv-editor-spec.coffee).

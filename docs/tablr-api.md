<img src='http://abe33.github.io/atom-tablr/heading.svg' width='858' height='50'>

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

The following classes are exposed by the service:

Class|Role
--|--
`Table`|The `Table` model is lowest level in Tablr hierarchy. Its main purpose is to handle the raw data: the columns and the rows that constitute a table. It also provides basic mechanisms to save the model on disk when provided with a save handler. Lastly it will handle the `modified` state of the table and provides the undo/redo mechanism.
`DisplayTable`|The `DisplayTable` model handles the display state of a `Table` object, like the size of rows and columns, the sort to apply to the table and the alignment to use for each column.
`TableEditor`|The `TableEditor` model is the upper model in the hierarchy, it composes a `DisplayTable` and provides the controls necessary to modify it. It stores the cursors and selections the user can manipulate and handles the copy/paste operation.
`Range`|When manipulating a table you can use the Atom's `Point` class, but ranges in a table are expressed differently than in a text editor. This model mimic the `Range` class from Atom but adjusted to the table specificities.

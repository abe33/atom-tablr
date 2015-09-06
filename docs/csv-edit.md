## Edit A CSV File

This package provides a specific opener for `CSV` files that will allow you to choose between editing the file as text or with the table editor.

![CSV Opener](https://github.com/abe33/atom-table-edit/blob/master/resources/csv-opener.png?raw=true)

As you can see in the screenshot above, there's a bunch of settings available before opening a file with the table editor. This is necessary as `CSV` isn't a [strictly defined format](https://en.wikipedia.org/wiki/Comma-separated_values) and delimiter and other options can't be guessed from the plain-text version. These settings aren't necessary when using the text editor mode but you can still set them, they'll be save for later use.

At the bottom of the panel lies the preview area. It displays a preview of the `.csv` file parsed using the current settings. If the file can't be parsed using the current configuration, a notice with the encountered error is displayed in place of the preview.

This panel will appear every time you open the same file using Atom open dialog or `fuzzy-finder`. You can check the `Remember my choice` checkbox to set once and for all how you want a file to be edited.

### CSV Settings

These settings are only used when using the `Table Editor` mode.

The [node-csv](https://github.com/wdavidw/node-csv) module is used to parse and serialize `.csv` files and so the settings available are mostly based on the ones supported by node-csv.

Setting|Description
---|---
`Row Delimiter`|The character used to separate each rows. By default it uses the `auto` mode that will use the typical newline of the host system.
`Column Delimiter`|The character used to separate each columns in a row. By default it uses a comma as delimiter.
`Quotes`|The character used to surround a field. Defaults to double quotes.
`Escape`|The character used to escape quotes in a quoted field. Defaults to a double quote.
`Comments`|The character used to differentiate comments from rows in the source. Defaults to a `#`.
`Trim`|How to treat space characters surrounding a field. By defaults they are not trimmed.
`Header`|If checked, the first row will be used to populate the table header. The header line will be also serialized along the rows on save.
`End Of File`|When checked, the file will always be saved with an extra empty line at the end.
`Quoted`|When checked, each field will be wrapped with the quote character on save.
`Skip Empty Lines`|When checked, the empty lines in the file will be ignored and no rows will be created for them.

As you probably noticed, many fields in the settings form have a `custom` option and an additional text input. This allow you to define your own values when they're not available in the predefined options. Starting to type in the text input will automatically set the option on `custom`, and removing all its content will make the setting come back to its default.

### Table Editor

![CSV Opener](https://github.com/abe33/atom-table-edit/blob/master/resources/table-editor.png?raw=true "In this screenshot the Header option was checked.")

Working with a table editor is done pretty much as you could expect. You can select one or many cells, edit them, copy/paste them and so on.

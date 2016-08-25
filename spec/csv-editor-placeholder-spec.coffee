require './helpers/spec-helper'

{CSVEditorPlaceholder} = require '../lib/csv-editor-placeholder'
CSVEditor = require '../lib/csv-editor'

describe 'CSVEditorPlaceholder', ->
  [state, placeholder, editor, jasmineContent, workspaceElement] = []

  beforeEach ->
    jasmineContent = document.body.querySelector('#jasmine-content')
    workspaceElement = atom.views.getView(atom.workspace)
    jasmineContent.appendChild(workspaceElement)

    styleNode = document.createElement('style')
    styleNode.textContent = "
    atom-workspace {
      z-index: 100000;
    }"

    firstChild = jasmineContent.firstChild

    jasmineContent.insertBefore(styleNode, firstChild)

    state = {
      deserializer: 'CSVEditor'
      filePath: "#{atom.project.getPaths()[0]}/sample.csv"
      options: {}
      choice: undefined
    }

    placeholder = new CSVEditorPlaceholder(state)

    atom.workspace.getActivePane().addItem(placeholder)

  describe 'when the package is activated', ->
    beforeEach ->
      waitsForPromise -> atom.packages.activatePackage('tablr')

    it 'replaces itself with a deserialized CSVEditor', ->
      expect(workspaceElement.querySelector('atom-csv-editor-placeholder')).not.toExist()
      expect(workspaceElement.querySelector('atom-csv-editor')).toExist()

      expect(atom.workspace.getActivePaneItem() instanceof CSVEditor).toBeTruthy()

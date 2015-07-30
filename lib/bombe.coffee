{CompositeDisposable} = require 'atom'
crypto = require './encryption'
Dialog = require './dialog'

module.exports = Cryptex =
  activate: (state) ->
    @subs = new CompositeDisposable
    @subs.add atom.workspace.observeTextEditors (ed) =>
      @handleOpen ed
    @subs.add atom.commands.add 'atom-text-editor',
      'bombe:encrypt-this-file': =>
        @encryptEditor()

  deactivate: () ->
    @subs.dispose()

  getPassword: (f) ->
    f 'foobar'

  prompt: (s, f) ->
    d = new Dialog
      iconClass: 'icon-lock'
      prompt: s
    d[0].querySelector('atom-text-editor').style.webkitTextSecurity = 'disc'
    d.onConfirm = (pw) =>
      f pw, d
    d.attach()

  chunk: (xs, n=80) ->
    for i in [0...xs.length] by n
      xs.slice i, i+n

  format: (s) -> @chunk(s).join('\n')

  encryptEditor: (ed = atom.workspace.getActiveTextEditor()) ->
    return if ed.bombe
    @getPassword (pw) =>
      ed.bombe = {key: pw, listener: @listenSave ed}

  listenSave: (ed) ->
    ed.onDidSave => @handleSave ed

  handleSave: (ed) ->
    return if ed.bombe.saving
    ed.bombe.saving = true
    text = ed.getText()
    {key} = ed.bombe
    enc = 'bombe-aes192\n' + @format crypto.encode text, key
    ed.setText enc
    ed.save()
    delete ed.bombe.saving
    ed.getBuffer().cachedDiskContents = text
    ed.undo()
    ed.undo()

  handleOpen: (ed) ->
    ls = ed.getBuffer().getLines()
    if ls[0] == 'bombe-aes192'
      ls.shift()
      enc = ls.join ''
      @getPassword (pw) =>
        # TODO: catch bad passwords
        text = crypto.decode enc, pw
        ed.getBuffer().cachedDiskContents = text
        ed.setText text
        ed.bombe = {key: pw, listener: @listenSave ed}

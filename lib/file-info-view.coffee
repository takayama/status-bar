{Disposable} = require 'atom'
url = require 'url'
fs = require 'fs-plus'

module.exports =
class FileInfoView
  constructor: ->
    @element = document.createElement('status-bar-file')
    @element.classList.add('file-info', 'inline-block')

    @currentPath = document.createElement('a')
    @currentPath.classList.add('current-path')
    @element.appendChild(@currentPath)
    @element.currentPath = @currentPath

    @element.getActiveItem = @getActiveItem.bind(this)

    @activeItemSubscription = atom.workspace.onDidChangeActivePaneItem =>
      @subscribeToActiveItem()
    @subscribeToActiveItem()

    @registerTooltip()
    clickHandler = (event) =>
      isShiftClick = event.shiftKey
      @showCopiedTooltip(isShiftClick)
      text = @getActiveItemCopyText(isShiftClick)
      atom.clipboard.write(text)
      setTimeout =>
        @clearCopiedTooltip()
      , 2000

    @currentPath.addEventListener('click', clickHandler)
    @clickSubscription = new Disposable => @currentPath.removeEventListener('click', clickHandler)

  registerTooltip: ->
    @tooltip = atom.tooltips.add(@element, title: ->
      "Click to copy file path")

  clearCopiedTooltip: ->
    @copiedTooltip?.dispose()
    @registerTooltip()

  showCopiedTooltip: (copyRelativePath) ->
    @tooltip?.dispose()
    @copiedTooltip?.dispose()
    text = @getActiveItemCopyText(copyRelativePath)
    @copiedTooltip = atom.tooltips.add @element,
      title: "Copied: #{text}"
      trigger: 'click'
      delay:
        show: 0

  getActiveItemCopyText: (copyRelativePath) ->
    activeItem = @getActiveItem()
    path = activeItem?.getPath?()
    # An item path could be a url, we only want to copy the `path` part
    if path?.indexOf('://') > 0
      path = url.parse(path).path

    return activeItem?.getTitle?() or '' if not path?

    if copyRelativePath
      atom.project.relativize(path)
    else
      path

  subscribeToActiveItem: ->
    @modifiedSubscription?.dispose()
    @titleSubscription?.dispose()

    if activeItem = @getActiveItem()
      @updateCallback ?= => @update()

      if typeof activeItem.onDidChangeTitle is 'function'
        @titleSubscription = activeItem.onDidChangeTitle(@updateCallback)
      else if typeof activeItem.on is 'function'
        #TODO Remove once title-changed event support is removed
        activeItem.on('title-changed', @updateCallback)
        @titleSubscription = dispose: =>
          activeItem.off?('title-changed', @updateCallback)

      @modifiedSubscription = activeItem.onDidChangeModified?(@updateCallback)

    @update()

  destroy: ->
    @activeItemSubscription.dispose()
    @titleSubscription?.dispose()
    @modifiedSubscription?.dispose()
    @clickSubscription?.dispose()
    @copiedTooltip?.dispose()
    @tooltip?.dispose()

  getActiveItem: ->
    atom.workspace.getActivePaneItem()

  update: ->
    @updatePathText()
    @updateBufferHasModifiedText(@getActiveItem()?.isModified?())

  updateBufferHasModifiedText: (isModified) ->
    if isModified
      @element.classList.add('buffer-modified')
      @isModified = true
    else
      @element.classList.remove('buffer-modified')
      @isModified = false

  updatePathText: ->
    if path = @getActiveItem()?.getPath?()
      @currentPath.textContent = fs.tildify(atom.project.relativize(path))
    else if title = @getActiveItem()?.getTitle?()
      @currentPath.textContent = title
    else
      @currentPath.textContent = ''

###
UNTV - virtual-keyboard
Author: Gordon Hall

Creates an on-screen keyboard for capturing user text input
###

fs             = require "fs"
jade           = require "jade"
$              = require "../../vendor/jquery-2.0.3"
{EventEmitter} = require "events"
Remote         = require "../remote"
common         = require "../common"

class VirtualKeyboard extends EventEmitter

  defaults =
    default: "alphanum"
    allow: [
      "alphanum"
      "symbols"
      "numeric"
    ]

  constructor: (@remote, @options = defaults) -> 
    if @remote not instanceof Remote then throw new TypeError """
      Value 'remote' is not an instance of Remote
    """

  view: jade.compile fs.readFileSync "#{__dirname}/../../views/keyboard.jade"

  prompt: (hint = "Enter text:", callback) =>
    @remote.sockets.emit "prompt:ask", message: hint
    # if a callback is specified, bind to the input event
    if typeof callback is "function" 
      @once "input", callback
      @remote.once "prompt:answer", (data) =>
        if data.value
          @emit "input", data.value
          @close()

    # compile the view
    compiled_view = @view hint: hint
    # remove any existing ui instance and replace with new one
    do @unbind
    # do @cacheRemoteListeners
    do @getView().remove
    # show keyboard, blur body, and show default keys
    ($ "body").append compiled_view
    ($ "#app").addClass "blurred"
    ($ ".vkeyboard[data-type='#{@options.default}']").show()
    ($ ".vkeyboard-value").focus()
    do @bind
    do @focusKey

  view_id: "vkeyboard"

  getView: => ($ "##{@view_id}")

  getCurrentKeyboard: => ($ ".vkeyboard:visible").first()

  getCurrentKey: => ($ "dd.focused", @getCurrentKeyboard())

  getAdjacentKeys: => 
    current_key   = @getCurrentKey()
    current_index = current_key.index() 
    current_row   = current_key.parent()
    prev_row      = current_row.prev()
    next_row      = current_row.next()
    top_key       = ($ "dd", prev_row)[current_index] or ($ "dd", prev_row).last()
    bottom_key    = ($ "dd", next_row)[current_index] or ($ "dd", prev_row).last()

    keys = 
      left: if current_key.prev().length then current_key.prev() else null 
      right: if current_key.next().length then current_key.next() else null
      top: if prev_row.length then $ top_key else null
      bottom: if next_row.length then $ bottom_key else null

  value: => ($ ".vkeyboard-value", @getView()).val()

  bind: =>
    # setup remote and keyboard bindings
    for event in @events
      @remote.on event.name, @[event.handler]

  unbind: =>
    # remove remote listeners
    for event in @events
      @remote.removeListener event.name, @[event.handler]

  cacheRemoteListeners: common.cacheRemoteListeners 
  rebindCachedListeners: common.rebindCachedListeners

  moveUp: =>
    keys = @getAdjacentKeys()
    @focusKey keys.top if keys.top

  moveDown: =>
    keys = @getAdjacentKeys()
    @focusKey keys.bottom if keys.bottom

  moveLeft: =>
    keys = @getAdjacentKeys()
    @focusKey keys.left if keys.left

  moveRight: =>
    keys = @getAdjacentKeys()
    @focusKey keys.right if keys.right

  selectKey: =>
    action = @getCurrentKey().attr "data-action"
    if action then @handleAction action
    else @type @getCurrentKey().text()

  confirm: =>
    do @unbind
    # do @rebindCachedListeners
    @emit "input", @value()
    do @close

  cancel: =>
    do @unbind
    # do @rebindCachedListeners
    @emit "input", null
    do @close

  close: =>
    @getView().fadeOut 200, => do @getView().remove
    ($ "#app").removeClass "blurred"

  focusKey: (key) =>
    if key and ($ key).hasClass "empty" then return
    keyboard = @getCurrentKeyboard()
    ($ "dd", keyboard).removeClass "focused"
    if key then ($ key).addClass "focused"
    else ($ "dd", keyboard).first().addClass "focused"

  type: (key = "") =>
    view  = @getView()
    value = @value()
    ($ ".vkeyboard-value", view).val "#{value}#{key}"

  backspace: =>
    view  = @getView()
    value = @value().substr 0, @value().length - 1
    ($ ".vkeyboard-value", view).val value 

  handleAction: (action) =>
    switch action
      when "backspace" then do @backspace
      when "space" then @type " "
      when "submit" then do @confirm

  switchKeyboard: =>
    keyboard = @getCurrentKeyboard()
    if keyboard.next().length then keyboard.next().show()
    else ($ ".vkeyboard").first().show()
    keyboard.hide()
    ($ ".vkeyboard-value").focus()
    do @focusKey

  events: [
    { name: "scroll:up", handler: "moveUp" }
    { name: "scroll:down", handler: "moveDown" }
    { name: "scroll:left", handler: "moveLeft" }
    { name: "scroll:right", handler: "moveRight" }
    { name: "go:select", handler: "selectKey" }
    { name: "go:back", handler: "cancel" }
    { name: "menu:toggle", handler: "cancel" }
    { name: "go:next", handler: "switchKeyboard" }
  ]

module.exports = VirtualKeyboard

###
UNTV - remote-server.coffee
Author: Gordon Hall

Sets up HTTP server for delivering the remote control interface 
and acts as the communication bus between the remote and tv player
###

{readFileSync}      = require "fs"
{EventEmitter}      = require "events"
{networkInterfaces} = require "os"
$                   = require "../vendor/jquery-2.0.3"

class Remote extends EventEmitter
  
  constructor: (@port=8080) ->
    # allow unlimited event listeners
    @setMaxListeners 0
    # import remote interface
    { @app, @server, @sockets } = require "untv-remote"
    # initialize
    do @subscribe
    do @bindKeyboard
    do @bindMousewheel

  listen: (callback) =>
    @server.listen @port, callback

  playEventSound: (sound = "keypress", volume = 0.2, start_at = 0) =>
    player         = window.document.createElement "audio"
    player.src     = "#{@event_sounds}/#{sound}.ogg#t=#{start_at}"
    player.name    = "remote-event-player"
    player.volume  = volume

    ($ player).bind "ended", -> do ($ player).remove
    ($ "body").append player
    do player.play

  event_sounds: "#{__dirname}/../assets/sounds"

  subscribe: =>
    @sockets.on "connection", (client) =>
      # inform any subscribers that the remote is connected
      @emit "remote:connected", client
      # inform when disconnected
      client.on "disconnect", => @emit "remote:disconnected"
      # proxy these events back up to our instance listeners
      bindings = @events.map (event) =>
        (=> client.on event, (data) => @emit event, data)
      bindings.forEach (bind) -> do bind

  bindKeyboard: =>
    keyboard = window.Mousetrap
    if "Mousetrap" not of window then return
    # setup keyboard bindings
    keyboard.bind "up", => 
      @emit "scroll:up"

    keyboard.bind "down", => 
      @emit "scroll:down"

    keyboard.bind "left", => 
      @emit "scroll:left"

    keyboard.bind "right", => 
      @emit "scroll:right"

    keyboard.bind "enter", => 
      @emit "go:select"

    keyboard.bind "pageup", => 
      @emit "go:back"

    keyboard.bind "pagedown", => 
      @emit "go:next"

    keyboard.bind "tab", (e) => 
      e.preventDefault()
      @emit "go:next"

    keyboard.bind "home", => 
      @emit "menu:toggle"

    keyboard.bind "escape", => 
      if @listeners("go:back").length then @emit "go:back" 
      else @emit "menu:toggle"

    keyboard.bind "space", => 
      unless window.document.activeElement?.tagName is "INPUT"
        @emit "player:toggle"

    keyboard.bind "shift+space", => 
      @emit "player:toggle"

    keyboard.bind "shift+right", => 
      @emit "player:next"
      
    keyboard.bind "shift+left", => 
      @emit "player:prev"

  bindMousewheel: =>
    # swiping up and down
    $(window).bind "mousewheel", (event) =>
      x_delta = event.originalEvent.wheelDeltaX
      y_delta = event.originalEvent.wheelDeltaY

      if y_delta
        if y_delta > 0 then @emit "scroll:up"
        else @emit "scroll:down"
        
      if x_delta
        if x_delta > 0 then @emit "scroll:left"
        else @emit "scroll:right"

    # making a selection - let's keep this commented for now
    # until we have better mouse support
    # $(window).bind "click", (event) => @emit "go:select"

  interfaces: =>
    interfaces = do networkInterfaces
    possible   = []
    for iface of interfaces
      for details in interfaces[iface]
        possible.push details if details.family is "IPv4" and not details.internal
    return possible

  events: [
    # global menu events
    "menu:toggle"
    # navigation events
    "go:next"
    "go:back"
    "go:select"
    # scroll events
    "scroll:up"
    "scroll:down"
    "scroll:left"
    "scroll:right"
    # player events
    "player:toggle"
    "player:next"
    "player:prev"
    "player:seek"
    # other actions
    "prompt:answer" # returned from `prompt:ask`
    "confirm:answer" # returned from `confirm:ask`
    "alert:dismissed" # returned from `alert:show`
  ]

module.exports = Remote

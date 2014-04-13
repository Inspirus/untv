###
UNTV - tv-player.coffee
Author: Gordon Hall

Defines a "player" instance that can be passed media for playback
###

{EventEmitter} = require "events"
$              = require "../vendor/jquery-2.0.3.js"
opensubs       = require "opensubtitles-client"
request        = require "request"
zlib           = require "zlib"
fs             = require "fs"
path           = require "path"
os             = require "os"
videosubs      = require "../vendor/videosub.js"

class Player extends EventEmitter
  constructor: (@container, @remote) ->
    # create audio player
    @audio            = window.document.createElement "audio"
    @audio.controls   = off
    @audio.autoplay   = yes
    @audio.src        = null
    @audio.onprogress = @informTime
    # @audio.is_playing = no
    
    # create video player
    @video            = window.document.createElement "video"
    @video.controls   = on
    @video.autoplay   = yes
    @video.height     = @height()
    @video.width      = @width()
    @video.src        = null
    @video.onprogress = @informTime
    # @video.is_playing = no
    # @video.poster     = "/assets/images/loader.gif"

    # subtitles api
    @subtitles = 
      api: opensubs.api
      token: null

    @subtitles.api.on "error", (err) -> 
      # handler open subs error silently (for now)

    @subtitles.api.login().done (token) => 
      @subtitles.token = token or null

    # listen for remote events
    do @subscribe

    # resize the video player
    ($ window).on "resize", =>
      @video.height = @height()
      @video.width  = @width()

    # ($ [@video, @audio]).on "playing", -> @is_playing = yes
    # ($ [@video, @audio]).on "ended", -> @is_playing = no

    # handle errors
    ($ @video).on "error", (err) => do @showErrorMessage
    ($ @audio).on "error", (err) => do @showErrorMessage

  width: -> ($ window).width()
  height: -> ($ window).height()

  active_player: null

  play: (src, media_type) =>
    @video.height = @height()
    @video.width  = @width()
    # if src and media type are passed, then update the player
    if src and media_type
      if media_type not in @media_types then throw "#{media_type} not supported"
      # set the active player
      @active_player     = @[media_type]
      @active_player.src = src
      # inject the active player into the container
      if not (@container.children media_type).length
        @container.html @active_player
        
    # otherwise go ahead and resume from where we left off if
    # there is an active media source
    if @active_player?.src
      do @container.show
      # play the media
      videosubs(@container)
      do @active_player.play #if not @active_player.is_playing
      @is_playing = yes
      # inform listeners
      @inform_interval = setInterval @informTime, 1000

  pause: (minimize) =>
    do @active_player?.pause
    @is_playing = no
    clearInterval @inform_interval
    do @container.hide if minimize

  seek: (time) ->
    @active_player?.currentTime = time if time isnt @duration()

  next: =>
    # seek by increment forward
    @remote.emit "player:seek", 
      position: @active_player?.currentTime + @seek_increment

  prev: =>
    # seek by increment backward
    @remote.emit "player:seek", 
      position: @active_player?.currentTime - @seek_increment

  seek_increment: 12000 # 12 secs

  duration: =>
    @active_player?.duration

  informTime: =>
    new_time = @active_player?.currentTime
    if @time < new_time
      # @is_playing = yes
      @time       = new_time
      @emit "player:progress", 
        duration: @duration()
        position: time
    # else
    #   @is_playing = no

  inform_interval: null

  subscribe: =>
    @remote.on "player:toggle", =>
      if @is_playing then do @pause else do @play
    @remote.on "player:next", @next
    @remote.on "player:prev", @prev
    # remote should pass a `position` parameter
    @remote.on "player:seek", (data) => @seek data.position
      
  media_types: [
    "video"
    "audio"
  ]

  showErrorMessage: (message) =>
    @notifier?.notify "Player", message or "Failed to play media", yes
    @pause yes

  loadSubtitles: (lang, movie, callback) =>
    token = @subtitles.token
    
    if not token then return callback "Subtitles API not ready."
    
    @subtitles.api.search(token, lang, movie).done (results) =>
      if results.length is 0 then return callback "Subtitles not found"
      
      first_match = results[0].SubDownloadLink
      target_path = "#{os.tmpdir()}/#{path.basename(first_match, '.gz')}.srt"
      input       = request first_match
      gunzip      = zlib.createGunzip()
      output      = fs.createWriteStream target_path

      input.pipe(gunzip).pipe(output)

      input.on "error", (err) => callback err
      gunzip.on "error", (err) => callback err
      output.on "error", (err) => callback err

      output.on "finish", => 
        @insertSubtitleTrack target_path, lang
        callback()

  insertSubtitleTrack: (path, lang) =>
    track = """<track kind="subtitles" src="file://#{path}" srclang="#{lang}">"""
    ($ @video).html track

  removeSubtitleTrack: => ($ @video).html ""

  # set up playlist subset
  playlist:
    items: []
    current_track: null

    add: (item, media_type) =>

    remove: (item) =>

    next: =>

    prev: =>

    empty: =>


module.exports = Player

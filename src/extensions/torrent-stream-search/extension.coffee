###
UNTV - torrent-stream-search extension
Author: Gordon Hall

Enables user to search for torrents using the Yifi JSON API and
stream them directly to the global player instance
###

fs            = require "fs"
TorrentSearch = require "./torrent-search"
localStorage  = window.localStorage
torrents      = new TorrentSearch()
async         = require "async"
opensub       = require "opensubtitles-client"

###
Pre-emptively Load Latest Movies and Cache
###
do torrents.latest

###
Initialize Extension 
###
module.exports = (env) ->
  torrent    = env.torrentStreamer
  config     = env.manifest.config
  disclaimer = (fs.readFileSync "#{__dirname}/disclaimer.html").toString()
  # re-instantiate TorrentSearch using socks5 config
  if config.use_socks5
    proxy =
      host: config.socks5_host
      port: config.socks5_port
  else
    proxy = null
  torrents = new TorrentSearch proxy

  # get dom containers
  container    = (env.gui.$ "#torrent-list")
  details_view = (env.gui.$ "#torrent-details")
  menu_view    = (env.gui.$ "#torrent-menu")
  header       = (env.gui.$ "header", env.view)

  ###
  Configure Virtual Keyboard
  ###
  keyboard_config = 
    default: "alphanum"
    allow: [
      "alphanum"
      "symbols"
    ]
  keyboard = new env.gui.VirtualKeyboard env.remote, keyboard_config
  
  ###
  Configure Movie Grid
  ###
  grid_config  = 
    adjust_x: menu_view.outerWidth()
    # adjust_y: header.outerHeight()
    # prevents auto row switch on bounds reached left/right
    smart_scroll: no 
    # prevents auto row sizing based on visibility of items
    smart_rows: no
    animation: "fadeInUp"
  # instantiate grid
  grid = new env.gui.NavigableGrid container, env.remote, grid_config
  
  ###
  Configure Menu List
  ###
  menu_config  = 
    # adjust_y: header.outerHeight()
    adjust_x: details_view.width()
    # enables scroll to top/bottom when scrolling past bottom/top
    smart_scroll: yes 
    # leaves the selection class on focus removal
    leave_decoration: yes
  # instantiate grid
  menu = new env.gui.NavigableList (env.gui.$ "ul", menu_view), env.remote, menu_config
  # auto give menu focus
  menu.giveFocus 1

  ###
  Auto Populate Newly Added (All Genres)
  ###
  list = JSON.parse localStorage.getItem "movies:latest:all" or []
  grid.populate list, torrents.compileTemplate "list"

  ###
  Menu List Event Handlers
  ###
  menu.on "item_focused", (item) ->
    input = (env.gui.$ "input", item)
    if input.length
      do input.focus
      env.remote.sockets.emit "prompt:ask", message: input.attr "placeholder"

  menu.on "item_selected", (item) ->
    action = item.attr "data-list-action"
    # handle search with vkeyboard here
    if action is "search"
      do menu.lock
      return keyboard.prompt "Search by movie title or keyword...", (text) =>
        if not text 
          do menu.unlock
          do menu.giveFocus
        else
          getTorrentMovies item, text
    else
      getTorrentMovies item
    

  menu.on "out_of_bounds", (data) ->
    switch data.direction
      # when "up"
      # when "down"
      when "right"
        do menu.releaseFocus
        do grid.giveFocus

  getTorrentMovies = (item, search) ->
    do menu.lock
    key   = item.attr "data-param-name"
    param = item.attr "data-list-param"

    query = 
      quality: "1080p"
      limit: 50
      keywords: search

    query[key] = param if param

    # load torrent list
    details_view.addClass "loading"
    torrents.list query, (err, list) ->
      do menu.unlock
      if err or not list
        env.notifier.notify env.manifest.name, err or "No Results", yes
        do menu.giveFocus
      else
        grid.populate list, torrents.compileTemplate "list"
        do grid.giveFocus
      details_view.removeClass "loading"

  ###
  Grid Event Handlers
  ###
  detail_requests = null
  grid.on "item_focused", (item) ->
    # kill any pending details request
    do detail_requests?.abort
    movie_id = (env.gui.$ ".movie", item).data "id"
    imdb_id  = (env.gui.$ ".movie", item).data "imdb"

    if imdb_id
      details_view.addClass "loading"
      detail_requests = getMovieDetails movie_id, imdb_id, (err, movieInfo) -> 
        details_view.removeClass "loading"
        if err then return
        details = torrents.compileTemplate "details"
        # render view
        (env.gui.$ "#torrent-details").html details movieInfo
      
      # if this is the last row in the grid, load the next 50 movies
      # but only if there is already more than one row loaded
      current_row   = grid.getCurrentRow()
      current_pos   = current_row.outerHeight() * current_row.siblings().length
      current_item  = grid.getCurrentItem()
      current_index = (env.gui.$ "li", grid.scroller).index current_item 

      if not current_row.next().length and current_row.prev().length
        item       = menu.last_item
        key        = item.attr "data-param-name"
        param      = item.attr "data-list-param"
        query      = 
          quality: "1080p"
          limit: 50
          set: (grid.data.length / 50) + 1
        query[key] = param

        # load torrent list
        grid.scroller.addClass "loading"
        torrents.list query, (err, list) ->
          if err or not list
            env.notifier.notify env.manifest.name, err or "No more movies to load.", yes
          else
            list = grid.data.concat list
            grid.populate list, torrents.compileTemplate "list"
          
          grid.scroller.removeClass "loading"
          grid.scroller.css "margin-top", "-#{current_pos}px"

          last_item = (env.gui.$ "li", grid.scroller)[current_index]
          grid.last_item_id = (env.gui.$ last_item).attr "data-navigrid-id"
          do grid.giveFocus

  grid.on "item_selected", (item) ->
    # show the details view and bind remote controls
    details_view.show()
    grid.releaseFocus()

    dismissMovie = -> 
      details_view.hide()
      grid.giveFocus()
      env.remote.removeListener "go:select", playMovie

    playMovie = ->
      env.remote.removeListener "go:back", dismissMovie
      env.notifier.notify env.manifest.name, "Preparing...", yes

      item_data    = (env.gui.$ ".movie", item).data()
      torrent_url  = item_data.torrent
      torrent_hash = item_data.hash
      movie_title  = (env.gui.$ "h2 .movie-title", details_view).text()

      # load subtitles if we can and should
      if config.use_subtitles
        env.player.loadSubtitles config.subtitles_language, movie_title, (err) ->
          if err
            env.player.removeSubtitleTrack()
            return env.notifier.notify "Error", err, yes
      else
        env.player.removeSubtitleTrack()

      torrent.consume torrent_url

      torrent.on "error", (err) ->
        # show error message
        env.notifier.notify env.manifest.name, err, yes
        dismissMovie()
        # do grid.giveFocus

      torrent.on "timeout", ->
        (env.gui.$ "#progress-loader").fadeOut(200)
        env.notifier.notify env.manifest.name, "Connection timed out.", yes
        dismissMovie()

      torrent.on "loading", ->
        # show loader
        (env.gui.$ "#progress-bar div").css width: "0%"
        (env.gui.$ "#progress-loader").fadeIn(200)

      torrent.on "progress", (percent) -> 
        (env.gui.$ "#progress-bar div").css width: "#{percent.loaded}%"

      torrent.on "ready", (file_info) ->
        # check codec support and open stream
        do torrent.stream

      torrent.on "stream", (stream_info) ->
        # pass `stream_url` to the player and show
        (env.gui.$ "#progress-loader").fadeOut(200)
        url = stream_info.stream_url
        env.player.play url, "video"

    env.remote.once "go:select", playMovie
    env.remote.once "go:back", dismissMovie

  grid.on "out_of_bounds", (data) ->
    switch data.direction
      # when "up"
      # when "down"
      when "left"
        do grid.releaseFocus
        do menu.giveFocus
      # when "right"

  getMovieDetails = (yifyId, imdbId, callback) ->
    aborted  = no
    async.parallel [
      (next) -> env.movieDB.movie.info imdbId, next
      (next) -> torrents.get yifyId, next
    ], (err, results) ->
      if err then return
      moviedb = results[0]
      yify    = results[1]
      base    = env.movieDB.config.images.base_url
      moviedb?.backdrop_path = "#{base}w1280#{moviedb.backdrop_path}"
      moviedb?.poster_path = "#{base}w342#{moviedb.poster_path}"
      if not aborted then callback null, { yify, moviedb }
    return {
      abort: -> aborted = yes
    }

  # show disclaimer after all bindings are set up
  env.notifier.notify env.manifest.name, disclaimer if config.show_disclaimer

###
UNTV - tv-shows-rss extension
Author: Gordon Hall

Enables user to browse tv shows using rss and using
magnet link to torrent episodes
###

# process.env.NODE_TLS_REJECT_UNAUTHORIZED = 0

ShowFeed = require "./show-feed"
fs       = require "fs"
jade     = require "jade"
async    = require "async"
request  = require "request"

###
Initialize Extension 
###
module.exports = (env) ->
  # get the rss feed wrapper
  config         = env.manifest.config
  torrent        = env.torrentStreamer
  feed           = new ShowFeed()
  localStorage   = window.localStorage
  show_list_view = env.gui.$ "#shows-menu", env.view
  schedule_view  = env.gui.$ "#today-schedule", env.view
  episode_view   = env.gui.$ "#episode-list", env.view

  keyboard_config = 
    default: "alphanum"
    allow: [
      "alphanum"
      "symbols"
    ]
  keyboard = new env.gui.VirtualKeyboard env.remote, keyboard_config

  show_list_config  = 
    adjust_y: (env.gui.$ "h2", show_list_view).outerHeight()
    adjust_x: schedule_view.width()
    smart_scroll: yes 
    leave_decoration: yes

  episode_list_config  = 
    adjust_y: (env.gui.$ "h2", episode_view).outerHeight()
    adjust_x: show_list_view.width()
    smart_scroll: yes 
    leave_decoration: no

  show_list     = null
  schedule_list = null
  episode_list  = null
  # get today's schedule
  feed.getSchedule (err, shows) ->
    view = jade.compile fs.readFileSync "#{__dirname}/views/schedule.jade"
    view = view shows: shows
    (env.gui.$ ".list-container", schedule_view).html view
    schedule_view.removeClass "loading"
    # wire up navilist and shift focus
    schedule_list = new env.gui.NavigableList(
      (env.gui.$ "ul", schedule_view), 
      env.remote, 
      episode_list_config
    )

    schedule_list.on "out_of_bounds", (data) ->
      if data.direction is "left"
        schedule_list.releaseFocus()
        show_list.giveFocus()
        
    schedule_list.on "item_selected", (item) ->
      torrents = JSON.parse item.attr "data-torrents"
      magnet   = item.attr "data-magnet"
      loadTorrentFromSources torrents
      # openTorrentStream magnet

  feed.on "error", (err) -> env.notifier.notify env.manifest.name, err, true

  feed.on "ready", ->
    # create navilist of all shows
    list = jade.compile fs.readFileSync "#{__dirname}/views/show-item.jade"

    (env.gui.$ "ul", show_list_view).html list shows: feed.shows

    show_list = new env.gui.NavigableList(
      (env.gui.$ "ul", show_list_view), 
      env.remote, 
      show_list_config
    )
    show_list.giveFocus 0

    show_list.on "out_of_bounds", (data) ->
      if schedule_list and schedule_view.is ":visible"
        target = schedule_list
      else if episode_list and episode_view.is ":visible"
        target = episode_list
      else
        target = null

      if data.direction is "right" and target
        show_list.releaseFocus()
        target.giveFocus()

    # when the navilist item is selected, 
    # load all the episodes for that show
    show_list.on "item_selected", (item) ->
      action = item.attr "data-list-action"

      if action is "search"
        do show_list.lock
        return keyboard.prompt "Search by show title...", (text) =>
          if not text 
            do show_list.unlock
            do show_list.giveFocus
          else
            do show_list.unlock
            filterShowList text, show_list
      else
        loadShowById item.attr "data-show-id"

  # the back button should clear any search filter
  # and take us back to today's schedule
  env.remote.on "go:back", ->
    (env.gui.$ "li", show_list_view).show()
    episode_view.hide()
    schedule_view.show()

  filterShowList = (text, show_list) ->
    text  = text.toLowerCase()
    items = (env.gui.$ "li", show_list_view).not ".search"
    # hide all the non-matching shows
    items.each ->
      content = (env.gui.$ this).text().toLowerCase()
      if content.indexOf(text) is -1 then (env.gui.$ this).hide()
    
    if items.filter(":visible").length is 0 then items.show()
    else show_list.giveFocus items.filter(":visible").first().index()

  loadShowById = (show_id) ->
    schedule_view.hide()
    episode_view.html("").addClass("loading").show()
    feed.getFeed show_id, (err, episodes) ->
      if err then return env.notifier.notify env.manifest.name, err, yes
      view = jade.compile fs.readFileSync "#{__dirname}/views/episode-list.jade"
      view = view episodes: episodes
      episode_view.html(view).removeClass "loading"
      # wire up navilist and shift focus
      episode_list = new env.gui.NavigableList(
        (env.gui.$ "ul", episode_view), 
        env.remote, 
        episode_list_config
      )

      episode_list.on "out_of_bounds", (data) ->
        if data.direction is "left"
          schedule_list.releaseFocus()
          show_list.giveFocus()
        
      episode_list.on "item_selected", (item) ->
        torrents = JSON.parse item.attr "data-torrents"
        magnet   = item.attr "data-magnet"
        loadTorrentFromSources torrents
        # openTorrentStream magnet

      episode_list.giveFocus()

  openTorrentStream = (src) ->
    torrent.on "error", (err) ->
      env.notifier.notify env.manifest.name , err, yes

    torrent.on "ready", (file_info) ->
      console.log "ready!"
      do torrent.stream

    torrent.on "timeout", ->
      (env.gui.$ "#progress-loader").fadeOut(200)
      env.notifier.notify env.manifest.name, "Connection timed out.", true

    torrent.on "loading", ->
      # show loader
      (env.gui.$ "#progress-bar div").css width: "0%"
      (env.gui.$ "#progress-loader").fadeIn(200)

    torrent.on "progress", (percent) -> 
      # update loader with `percent.loaded`
      (env.gui.$ "#progress-bar div").css width: "#{percent.loaded}%"

    torrent.on "stream", (stream_info) ->
      # pass `stream_url` to the player and show
      (env.gui.$ "#progress-loader").fadeOut(200)
      url = stream_info.stream_url
      env.player.play url, "video"

    torrent.consume src, true

  loadTorrentFromSources = (sources) ->
    env.notifier.notify env.manifest.name, "Preparing...", true
    attempts = sources.map (src) ->
      return (next) ->
        try
          # make sure the remote file is available
          req = request src
          req.on "response", (res) ->
            if res.statusCode isnt 200 then next null, src
            else openTorrentStream src
        catch err
          console.log err
          next null, src

    async.series attempts, (err, src) ->
      env.notifier.notify env.manifest.name, "Failed to load episode.", true

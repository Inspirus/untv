###
UNTV - video-library extension
Author: Gordon Hall

Enables user to browse their local hard disk or attached
devices or mounted disks for videos and play them
###

ffmpeg       = require "fluent-ffmpeg"
{Metadata}   = ffmpeg
fs           = require "fs"
jade         = require "jade"
async        = require "async"
path         = require "path"
os           = require "os"
localStorage = window.localStorage

module.exports = (env) ->

  conf          = env.manifest.config
  selector_view = (env.gui.$ "#files", env.view)
  grid_view     = (env.gui.$ "#movie-files")
  header        = (env.gui.$ "header", env.view)

  ###
  Supported File Type
  ###
  supported_types = [
    ".mp4"
    ".m4v"
    ".mov"
    ".mkv"
    ".avi"
    ".webm"
  ]

  ###
  Movie File Data Retrieval
  ###
  getMovieData = (movie, done) ->
    # get metadata
    meta = new Metadata movie.path, (data, err) ->
      if err then return done err
      movie.metadata = data
      # generate thumbnail
      proc = new ffmpeg source: movie.path
      proc.withSize "150x100"
      proc.takeScreenshots
        count: 1
        timemarks: ["25%", "50%", "75%"]
        filename: "%b_screenshot_%w_%i"
      , os.tmpdir(), (err, filenames) ->
        if err then console.log err

        movie.screenshots = (filenames or []).map (screen) -> 
          "#{os.tmpdir()}/#{screen}"

        movie.error = err or null
        done null, movie

  ###
  Load FileSelector
  ###
  file_config =
    adjust_y: 0
    adjust_x: grid_view.width()
    # enables scroll to top/bottom when scrolling past bottom/top
    smart_scroll: yes 
    # leaves the selection class on focus removal
    leave_decoration: yes
    # set initial path to last one
    initial_path: localStorage.getItem "videos:last_directory"
  file_selector = new env.gui.FileSelector selector_view, env.remote, ["*"], file_config

  # when a directory is opened, we should load up the videos
  # in another NavigableList, and use ffmpeg to generate thumbs
  file_selector.on "dir_selected", (data) ->
    # remember path
    localStorage.setItem "videos:last_directory", data.path
    # show loading indicator
    do movie_grid.container.empty
    movie_grid.container.addClass "loading"
    # get movies from directory
    dir_path = data.path
    # load movie list and get it's metadata
    contents = fs.readdirSync dir_path
    # filter by supported types
    movies   = contents.filter (mov) -> (path.extname mov) in supported_types
    # transform movie data to get more info
    movies   = movies.map (movie) ->
      stats: fs.statSync "#{dir_path}/#{movie}"
      name: path.basename movie, path.extname movie
      path: "#{dir_path}/#{movie}"
    # now build an async map to add screenshots and metadata, before passing to
    # the movie grid's populate template
    async.mapLimit movies, conf.ffmpeg_procs, getMovieData, (err, list_data) ->
      # console.log list_data
      if err then return err
      # compile template and replace container contents
      movie_grid.populate list_data or [], grid_template
      # hide loading indicator
      movie_grid.container.removeClass "loading"
    
  # when navigating right, switch focus to the movie grid
  file_selector.on "out_of_bounds", (data) ->
    switch data.direction
      when "right"
        do file_selector.selector.releaseFocus
        do movie_grid?.giveFocus

  ###
  Load Movie Grid
  ###
  movie_grid_config = 
    # adjust_y: header.outerHeight()
    adjust_x: selector_view.width()
    smart_scroll: no 
    smart_rows: yes
  grid_view_raw  = fs.readFileSync "#{__dirname}/views/movie-files.jade"
  grid_template  = jade.compile grid_view_raw.toString()
  # create new movie_list
  movie_grid = new env.gui.NavigableGrid grid_view, env.remote, movie_grid_config

  # if we empty the grid by populating with no movies, then show an
  # appropriate message in the container
  movie_grid.on "emptied", (container) ->
    view = fs.readFileSync "#{__dirname}/views/no-movies.jade"
    container.html do jade.compile view

  # when selecting a movie file, go ahead and load it and pass it's 
  # absolute path to the player instance
  movie_grid.on "item_selected", (item) ->
    movie_file_path = (env.gui.$ ".local-movie", item).attr "data-path"
    env.player.play movie_file_path, "video"

  # when navigating out of bounds left from movie grid, focus on the
  # file selector
  movie_grid.on "out_of_bounds", (data) ->
    switch data.direction
      when "left"
        do movie_grid.releaseFocus
        file_selector.selector.giveFocus 1

  # when the extension loads, go ahead and load the current directory movies
  file_selector.emit "dir_selected", 
    path: file_selector.current_path

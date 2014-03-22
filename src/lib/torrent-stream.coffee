###
UNTV - torrent-stream class
Author: Gordon Hall
###

url            = require "url"
fs             = require "fs"
{EventEmitter} = require "events"
request        = require "request"
os             = require "os"
nt             = require "nt"
peerflix       = require "peerflix"
path           = require "path"

class TorrentStream extends EventEmitter
  constructor: ->
    @on "error", =>
      if @video_stream and @video_stream.destroy then do @video_stream.destroy

  consume: (@torrent_location, letPeerflixDownload) =>
    # torrent_location may be a url to download
    # or it may be a local file path from which to read
    if letPeerflixDownload
      console.log "letting peerflix download torrent"
      @target_path = @torrent_location
      @emit "ready"
    else  
      switch @determineType()
        when "remote" then do @download
        when "local" then do @read

  determineType: =>
    if (url.parse @torrent_location).host? then "remote" else "local"

  download: =>
    tmp_dir      = os.tmpDir()
    filename     = path.basename (url.parse @torrent_location).path
    @target_path = "#{tmp_dir}/#{filename}"
    download     = request @torrent_location
    file_target  = fs.createWriteStream @target_path
    # when ready, read from disk
    file_target.on "finish", => do @read
    # handle any errors
    download.on "error", (err) => @emit "error", err
    file_target.on "error", (err) => @emit "error", err
    # download the file
    download.pipe file_target

  read: =>
    nt.read @target_path, (err, torrent) =>
      if err then @emit "error", err
      else @emit "ready", 
        info: torrent.infoHash()
        metadata: torrent.metadata

  cleanUp: =>
    if @loadingInterval then clearInterval @loadingInterval
    if @video_stream and @video_stream.destroy then do @video_stream.destroy
    if @video_stream and @video_stream.clearCache then do @video_stream.clearCache
    delete @video_stream

  stream: =>
    do @cleanUp
    console.log "opening stream..."
    @video_stream = peerflix @target_path, @options, (err, flix) => 
      if err
        console.log err
        return @emit "error", err

      @loadingInterval = setInterval => 
        @checkLoadingProgress @video_stream
      , 300

      @waitingTimeout = setTimeout =>
        if @percent < 1 then @emit "timeout"
      , @TIMEOUT_LENGTH

      @emit "loading"

      flix.server.on "listening", =>
        console.log "streaming server opened"
        
  TIMEOUT_LENGTH: 90000 # 90 seconds
  MIN_PERCENTAGE_LOADED: 0.5
  MIN_SIZE_LOADED: 10 * 1024 * 1024

  checkLoadingProgress: (flix) =>
    now                 = flix.downloaded
    total               = flix.selected.length
    targetLoadedSize    = @MIN_SIZE_LOADED > total ? total : MIN_SIZE_LOADED
    targetLoadedPercent = @MIN_PERCENTAGE_LOADED * total / 100.0
    targetLoaded        = Math.max targetLoadedPercent, targetLoadedSize
    @percent            = now / targetLoaded * 100.0

    if @percent > 99
      if @loadingInterval then clearInterval @loadingInterval
      if @waitingTimeout then clearTimeout @waitingTimeout
      @emit "stream", stream_url: "http://localhost:#{@options.port}"

    @emit "progress", loaded: @percent

  options:
    port: 8888
    connections: 100

module.exports = TorrentStream

###
UNTV - show-feed class
Author: Gordon Hall
###

{EventEmitter} = require "events"
FeedParser     = require "feedparser"
request        = require "request"
cheerio        = require "cheerio"

class ShowFeed extends EventEmitter
  constructor: (showId) ->
    @shows = []
    @getShows()

  getSchedule: (callback) =>
    @getFeed "all", callback

  getFeed: (showId, callback) =>
    show = @getShowById(showId) or {}
    self = this

    if show.episodes then return callback null, show.episodes

    show.feed     = request "http://showrss.info/feeds/#{showId}.rss"
    show.parser   = new FeedParser()
    show.episodes = []

    show.feed.on "response", (res) ->
      stream = this
      if res.statusCode isnt 200
        return self.emit "error", new Error "Bad status code"
      stream.pipe show.parser

    show.parser.on "error", (error) -> callback error

    show.parser.on "readable", ->
      stream = this
      meta   = @meta

      while item = do stream.read
        show.episodes.push self.parse item 
        
    show.parser.on "end", ->
      callback null, show.episodes

  parse: (item) =>
    data          = {} 
    parts         = item.title.split /([0-9]*x[0-9]*)/
    data.title    = item['showrss:showname']['#']
    data.season   = parts[1]?.split("x")[0]
    data.episode  = 
      title: parts[2]?.split("720p")[0].trim()
      number: parts[1]?.split("x")[1]
    data.link     = item.link
    data.torrents = @getTorrentURLFromMagnet data.link
    data.id       = item['showrss:showid']['#']
    data.date     = new Date item.pubdate
    return data

  getShowById: (showId) =>
    for show in @shows
      if show.id is showId then return show
    return null

  getShows: =>
    request "http://showrss.info/?cs=browse", (err, data) =>
      if err then return @emit "error", err
      $    = cheerio.load(data.body);
      self = this

      ($ "#browse_show option").each ->
        self.shows.push 
          id: ($ this).val()
          title: ($ this).html()
      
      @emit "ready", @shows

  getTorrentURLFromMagnet: (magnet_uri) ->
    magnet_uri = magnet_uri.replace /^\s+/, ""
    if magnet_uri.length is 0 then throw "no magnet specified"
    a1 = magnet_uri.indexOf "xt=urn:btih:"
    if a1 is -1 then throw "broken magnet link"
    a2 = magnet_uri.indexOf "&", a1
    a1 += 12;
    if a2 is -1 then magnet_uri = magnet_uri.substring a1
    else magnet_uri = magnet_uri.substring a1, a2
    if magnet_uri.length is 0 then throw "broken magnet link"
    magnet_uri = magnet_uri.toUpperCase()
    return [
      "http://torcache.net/torrent/#{magnet_uri}.torrent"
      "https://zoink.it/torrent/#{magnet_uri}.torrent"
    ]



module.exports = ShowFeed

###
UNTV - torrent-search class
Author: Gordon Hall
###

request      = require "request"
jade         = require "jade"
fs           = require "fs"
qstring      = require "querystring"
Socks5Agent  = require "socks5-http-client/lib/Agent"
localStorage = window.localStorage

class TorrentSearch
  constructor: (@proxy) ->
    @history = []
    console.log @proxy
    if @proxy
      unless @proxy.host and @proxy.port then @proxy = null

    console.log @proxy

  base_url: "http://yts.im/api/" # should be good in the UK and Malaysia
  # other options are:
  # "http://yts.re/api/" 
  # "http://yify-torrents.com/api/"
  data_type: "json"

  templates:
    upcoming: fs.readFileSync "#{__dirname}/views/upcoming-list.jade"
    list: fs.readFileSync "#{__dirname}/views/results-list.jade"
    details: fs.readFileSync "#{__dirname}/views/torrent-details.jade"

  compileTemplate: (template_name) =>
    if not template_name in @templates then throw "Invalid Template: #{template_name}"
    jade.compile @templates[template_name]

  upcoming: (callback) =>
    options = 
      url: "#{@base_url}upcoming.#{@data_type}"

    if @proxy
      options.agent = new Socks5Agent 
        socksHost: @proxy.host
        socksPort: @proxy.port

    request options, (err, response, body) =>
      if response and response.statusCode is 200
        try 
          data = results: JSON.parse body
          if callback then callback null, data.results.MovieList
        catch parseErr
          if callback then callback "Malformed response! Has your ISP blocked access?"
      else
        if @proxy then add_msg = "Is your proxy working?" else add_msg = ""
        if callback then callback "Failed to fetch movies! #{add_msg}"

  list: (data, callback) =>
    query = qstring.stringify data or {}
    options = 
      url: "#{@base_url}list.#{@data_type}?#{query}"

    if @proxy
      options.agent = new Socks5Agent 
        socksHost: @proxy.host
        socksPort: @proxy.port

    request options, (err, response, body) =>
      if response and response.statusCode is 200
        try 
          # console.log body
          data = results: JSON.parse body
          # console.log data
          if callback then callback null, data.results.MovieList
        catch parseErr
          if callback then callback "Malformed response! Has your ISP blocked access?"
      else
        if @proxy then add_msg = "Is your proxy working?" else add_msg = ""
        if callback then callback "Failed to fetch movies! #{add_msg}"

  # latest should get us the default sort 
  latest: (callback) => 
    @list 
      quality: "1080p"
      limit: 50
    , (err, list) ->
      if callback then callback err, list
      if not err and list
        localStorage.setItem "movies:latest:all", JSON.stringify list

  get: (id, callback) =>
    request "#{@base_url}movie.#{@data_type}?id=#{id}", (err, response, body) =>
      if response and response.statusCode is 200
        try 
          data = JSON.parse body
          if callback then callback null, data
        catch parseErr
          if callback then callback "Malformed response! Has your ISP blocked access?"
      else
        if typeof callback is "function" then callback err

  calculateHealth: (seeds = 0, peers = 0) ->
    ratio = if peers > 0 then (seeds / peers) else seeds
    # options are: poor, okay, good, great
    if seeds < 100 then "poor"
    else if seeds > 100 and seeds < 200
      if ratio > 5 then "good"
      else if ratio > 3 then "okay"
      else "poor"
    else if seeds > 200
      if ratio > 5 then "great"
      else if ratio > 3 then "good"
      else if ratio > 2 then "okay"
      else "poor"

module.exports = TorrentSearch

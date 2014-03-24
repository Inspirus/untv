###
UNTV - torrent-search class
Author: Gordon Hall
###

request      = require "request"
jade         = require "jade"
fs           = require "fs"
qstring      = require "querystring"
localStorage = window.localStorage

class TorrentSearch
  constructor: ->
    @history = []

  base_url: "http://yts.re/api/" # "http://yify-torrents.com/api/"
  data_type: "json"

  templates:
    upcoming: fs.readFileSync "#{__dirname}/views/upcoming-list.jade"
    list: fs.readFileSync "#{__dirname}/views/results-list.jade"
    details: fs.readFileSync "#{__dirname}/views/torrent-details.jade"

  compileTemplate: (template_name) =>
    if not template_name in @templates then throw "Invalid Template: #{template_name}"
    jade.compile @templates[template_name]

  upcoming: (callback) =>
    request "#{@base_url}upcoming.#{@data_type}", (err, response, body) =>
      if response and response.statusCode is 200
        try 
          data = results: JSON.parse body
          if callback then callback null, data?.MovieList
        catch parseErr
          if callback then callback "Malformed response! Has your ISP blocked access?"
      else
        if callback then callback "Failed to fetch movies!"

  list: (data, callback) =>
    query = qstring.stringify data or {}
    request "#{@base_url}list.#{@data_type}?#{query}", (err, response, body) =>
      if response.statusCode is 200
        try 
          data = results: JSON.parse body
          if callback then callback null, data?.MovieList
        catch parseErr
          if callback then callback "Malformed response! Has your ISP blocked access?"
      else
        if callback then callback "Failed to fetch movies!"

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

module.exports = TorrentSearch

###
UNTV - file-selector
Author: Gordon Hall

Accepts a starting path and creates a NavigableList
instance that allows for traversing the file system
###

fs             = require "fs"
path           = require "path"
jade           = require "jade"
NavigableList  = require "./navigable-list"
$              = require "../../vendor/jquery-2.0.3"
{EventEmitter} = require "events"
extend         = require "node.extend"

class FileSelector extends EventEmitter
  constructor: (@container, @remote, @ignore_types = [], @list_config = {}) ->
    ###
    ignore_types is an array of file extensions like ".txt"
    passing an empty string as an item will ignore all directories
    and only honor files, while passing a wildcard *, only directories
    will be honored
    ###
    home_env      = if process.platform is "win32" then "USERPROFILE" else "HOME"
    @home_dir     = process.env[home_env]
    @current_path = @home_dir
    # override if needed
    if @list_config.initial_path and fs.existsSync @list_config.initial_path
      @current_path = @list_config.initial_path
    do @update

  # call this when selecting a directory item
  update: (@current_path = @current_path) =>
    @current_tree = fs.readdirSync @current_path
    @parent_dir   = path.join @current_path, ".."
    # stat all the contents
    @current_tree = @current_tree.map (file) =>
      # get file stats
      try  
        stats = fs.statSync path.join @current_path, file
      catch err
        console.log(err)
        return false
      # ignore types
      if (path.extname file) in @ignore_types then no
      # check if ignore all files (wildcard)
      else if "*" in @ignore_types and stats.isFile() then no
      # ignore hidden
      else if (file.charAt 0) is "." then no
      # otherwise add to list
      else data = 
        path: path.join @current_path, file
        name: file
        stats: stats
    # add parent as item to current tree
    @current_tree.unshift 
      path: @parent_dir
      name: "Up To Parent"
      stats: fs.statSync @parent_dir
    # clean the tree array
    do @pruneTree
    # emit an event alerting listeners that we have file contents
    @emit "tree_loaded", files: @current_tree
    # render the instance
    do @render

  # draw interface
  render: =>
    ($ @container).html @template @current_tree
    # configure list
    selector_config = 
      adjust_y: 0
      adjust_x: 0
      smart_scroll: yes 
      leave_decoration: yes
    # extend default config
    selector_config = extend selector_config, @list_config
    ###
    we had a performance problem here...
    seems as if the NavigableList instances from previous
    calls to this render method were lost in memory somewhere
    but still listening for events

    at least calling `lock()` removed the visible performance hit
    but we need to manually collect the garbage i think...
    ###
    do @selector?.lock
    # create selector instance
    @selector = new NavigableList ($ "ul", @container), @remote, selector_config
    @selector.giveFocus 1
    do @subscribe
  
  # removes falsy values from the current_tree
  pruneTree: =>
    staging_tree = []
    for file in @current_tree
      staging_tree.push file if file
    @current_tree = staging_tree 

  # compiles view template
  template: (data) =>
    @template_file ?= fs.readFileSync "#{__dirname}/../../views/file-selector.jade"
    template        = jade.compile @template_file.toString()
    # return compiled template
    template files: data or @current_tree

  # set up events
  subscribe: =>
    # subscribe to events from NavigableList instance
    if not @selector then throw """
      Cannot subscribe to NavigableList, because it has not yet been instantiated
    """
    # when a directory is selected, open that directory
    # repopulating the file selector list and emitting 
    # another `tree_loaded` event
    @selector.on "item_selected", (item) =>
      item_type = item.attr "data-type"
      item_path = item.attr "data-path"
      # if it's a directory, set the current path and update
      if item_type is "directory"
        @update item_path
        @emit "dir_selected", path: item_path
      # otherwise, notify listeners of the file selected
      else if item_type is "file" then @emit "file_selected", path: item_path
      else throw "'#{item_type}' is not a valid parameter"
    # proxy the out of bounds event
    @selector.on "out_of_bounds", (data) => @emit "out_of_bounds", data

module.exports = FileSelector

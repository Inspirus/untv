###
UNTV - navigable-grid
Author: Gordon Hall

Accepts an unordered list selector or element and creates
a navigable grid instance
###

SmartAdjuster  = require "./smart-adjuster"
$              = require "../../vendor/jquery-2.0.3"
{EventEmitter} = require "events"
hat            = require "hat"

class NavigableGrid extends EventEmitter
  constructor: (@container, @remote, @config) ->
    # handle default config
    @config.adjust_y     ?= 0
    @config.adjust_x     ?= 0
    @config.smart_scroll ?= yes
    @config.smart_rows   ?= yes
    @config.animation    ?= ""

    @container = $ @container
    @container.css overflow: "hidden"

    ($ window).bind "resize", => do @populate
    do @bindRemoteControls

  populate: (list_data, template_fn) =>
    @data         = list_data if list_data
    @render      ?= template_fn or ->
    @last_item_id = null

    @container.empty()

    # check if there are items in the list data
    # and if not, then just return and emit an event
    if not @data or not @data.length then return @emit "emptied", @container

    @scroller  = $ "<div class='navigrid'/>"
    @container.append @scroller
    # determine the size of a single list item template
    pseudo_item   = $ "<li/>"
    # pseudo_item.css opacity: 0
    pseudo_item.html @render @data?[0]
    @scroller.append pseudo_item
    # use smart adjuster to size the container
    # first get x and y adjuster sizes
    @adjuster = new SmartAdjuster @container, @config.adjust_y, @config.adjust_x
    # determine size of container and items
    item_width   = pseudo_item.outerWidth()
    item_height  = pseudo_item.outerHeight()
    row_items    = Math.floor @adjuster.width / item_width
    total_rows   = Math.ceil @data.length / row_items
    @row_width   = item_width * row_items
    rows_visible = Math.floor @adjuster.height / item_height
    @row_height  = if @config.smart_rows then (@adjuster.height / rows_visible) else item_height + 12 
    # create a set of <ul>'s containing <li>'s consistent
    # with the width of the container
    row_counter = 0
    # for every row we expect, create an <ul>
    @scroller.empty()
    @scroller.append $ "<ul/>" for row in [0..total_rows]
    # setup width and height of rows
    rows = $ "ul", @container
    rows.width @row_width
    rows.height @row_height
    rows.addClass "animated"
    # add animation class
    rows.addClass @config.animation

    for item, index in @data
      next_row = index isnt 0 and (index % row_items) is 0
      # determine whether or not to add to next row
      if next_row then row_counter++
      target_row = $ rows[row_counter]
      # append output to the target row
      grid_item = $ "<li />"
      grid_item.attr "data-navigrid-id", hat()
      grid_item.html @render item
      # insert into grid
      target_row.append grid_item
      # -- leave this commented for now, mouse support in this manner sucks
      # -- and does more to confise the user than anything else
      # bind mouse
      # ($ "*", grid_item).hover (event) =>
      #   unless ($ event.target).closest("li").hasClass @selected_item_classname
      #     id = ($ event.target).closest("li").attr "data-navigrid-id"
      #     ($ "li", @scroller).removeClass @selected_item_classname
      #     # track focus
      #     @last_item    = ($ event.target).closest("li").addClass @selected_item_classname
      #     @last_item_id = @last_item.attr "data-navigrid-id"
      #     @emit "item_focused", @last_item

    # temp hack for extra ul
    do @pruneRows

  pruneRows: =>
    ($ "ul", @scroller).each -> do ($ @).remove if ($ @).children().length is 0

  nextItem: =>
    adjacent = do @adjacent
    if adjacent.right.length
      @remote.playEventSound "click", 0.2, 0.3
      @getCurrentItem().removeClass @selected_item_classname
      ($ adjacent.right).addClass @selected_item_classname

    else if @getCurrentRow().next().length and @config.smart_scroll
      ($ "li", @getCurrentRow().next()).first().addClass @selected_item_classname
      @last_item.removeClass @selected_item_classname
      @scroll "down"

    else
      @emit "out_of_bounds", direction: "right"

    # reference this item as the last one touched
    @last_item = do @getCurrentItem
    # emit event for select
    @emit "item_focused", @last_item

  prevItem: =>
    adjacent = do @adjacent
    if adjacent.left.length
      @remote.playEventSound "click", 0.2, 0.3
      @getCurrentItem().removeClass @selected_item_classname
      ($ adjacent.left).addClass @selected_item_classname

    else if @getCurrentRow().prev().length and @config.smart_scroll
      ($ "li", @getCurrentRow().prev()).last().addClass @selected_item_classname
      @last_item.removeClass @selected_item_classname
      @scroll "up"

    else
      @emit "out_of_bounds", direction: "left"
      
    # reference this item as the last one touched
    @last_item = do @getCurrentItem
    # emit event for select
    @emit "item_focused", @last_item

  nextRow: =>
    adjacent = do @adjacent
    if not @is_scrolling
      if adjacent.below
        @getCurrentItem().removeClass @selected_item_classname
        ($ adjacent.below).addClass @selected_item_classname
        @scroll "down"
        # reference this item as the last one touched
        @last_item = do @getCurrentItem
        # emit event for select
        @emit "item_focused", @last_item
      else
        @emit "out_of_bounds", direction: "down"

  prevRow: =>
    adjacent = do @adjacent
    if not @is_scrolling
      if adjacent.above
        @getCurrentItem().removeClass @selected_item_classname
        ($ adjacent.above).addClass @selected_item_classname
        @scroll "up"
        # reference this item as the last one touched
        @last_item = do @getCurrentItem
        # emit event for select
        @emit "item_focused", @last_item
      else
        @emit "out_of_bounds", direction: "up"

  giveFocus: =>
    @focused = yes
    @scroller.addClass @focused_area_classname
    ($ "li", @scroller).removeClass @selected_item_classname

    if @last_item_id
      @last_item = ($ "li[data-navigrid-id='#{@last_item_id}']")
      @last_item.addClass @selected_item_classname
    else
      @scroller.css "margin-top", "0px"
      @last_item = ($ "li", @scroller).first()
      @last_item.addClass @selected_item_classname
      @emit "item_focused", @last_item

  releaseFocus: =>
    @focused      = no
    @last_item_id = @getCurrentItem().data "navigrid-id"
    @last_item    = @last_item?.removeClass @selected_item_classname

    @scroller.removeClass @focused_area_classname
    ($ "li", @scroller).removeClass @selected_item_classname

  getCurrentItem: => $ "li.#{@selected_item_classname}", @container
  getCurrentRow: => @getCurrentItem().parent()

  adjacent: =>
    current = do @getCurrentItem
    index   = ($ "li", @getCurrentRow()).index current
    # return this stuff
    items   =
      above: ($ "li", current.parent().prev())[index] or null
      below: ($ "li", current.parent().next())[index] or null
      left:  current.prev() or null
      right: current.next() or null

  scroll: (direction = "down") =>
    @remote.playEventSound "click", 0.2, 0.3
    distance      = if direction is "up" then @row_height else -@row_height
    position      = if @last_item?.length then parseInt @scroller.css "margin-top" else 0
    @is_scrolling = yes
    target_margin = if @last_item?.length then position + distance else 0

    $.keyframe.define
      name: @scroll_keyframe_name
      from: "margin-top: #{position}px"
      to: "margin-top: #{target_margin}px"

    @scroller.playKeyframe
      name: @scroll_keyframe_name
      duration: @scroll_speed
      complete: => 
        @is_scrolling = no
        do ($ "style##{@scroll_keyframe_name}").remove
        @scroller.removeAttr "style" # hack to support dynamic keyframe overwrite
        @scroller.css "margin-top", "#{target_margin}px"

  scroll_keyframe_name: "navigrid-scroll"

  bindRemoteControls: =>
    @remote.on "scroll:up", => do @prevRow if @focused
    @remote.on "scroll:down", => do @nextRow if @focused
    @remote.on "scroll:right", => do @nextItem if @focused
    @remote.on "scroll:left", => do @prevItem if @focused
    @remote.on "go:select", => if @focused then @emit "item_selected", @getCurrentItem()

    # -- leave this commented for now, mouse support in this manner sucks
    # -- and does more to confise the user than anything else
    # setup mouse bindings
    # @container.bind "mouseenter", (event) => 
    #   console.log "mouseenter"
    #   @giveFocus()
    # @container.bind "mouseleave", (event) => 
    #   console.log "mouseleave"
    #   @releaseFocus()

  selected_item_classname: "navigrid-selected"
  focused_area_classname: "navigrid-focused"
  scroll_speed: 200

module.exports = NavigableGrid

###
UNTV - navigable-list
Author: Gordon Hall

Accepts an unordered list and create a navigable
list view
###

SmartAdjuster  = require "./smart-adjuster"
$              = require "../../vendor/jquery-2.0.3"
{EventEmitter} = require "events"

class NavigableList extends EventEmitter
  constructor: (@list_element, @remote, @config) ->
    # handle default config
    @config.adjust_y         ?= 0
    @config.adjust_x         ?= 0
    @config.smart_scroll     ?= no
    @config.leave_decoration ?= no
    # create scrolling wrapper
    @list_element = $ @list_element
    @scroller     = $ "<div class='navilist'/>"
    @scroller.css 
      overflow: "hidden"
      position: "fixed"
    @scroller = @list_element.wrap @scroller
    @adjuster  = new SmartAdjuster @scroller.parent(), @config.adjust_y, @config.adjust_x

    ($ window).bind "resize", => 
      if @last_item then @setScrollPosition @last_item 
      do @adjuster.adjust
    do @bindRemoteControls

  bindRemoteControls: =>
    @remote.on "scroll:right", => (@emit "out_of_bounds", direction: "right") if @focused
    @remote.on "scroll:left", => (@emit "out_of_bounds", direction: "left") if @focused
    @remote.on "go:select", => 
      @selected = @last_item
      (@emit "item_selected", @last_item) if @focused
    @remote.on "scroll:up", => do @prevItem if @focused # and not @scrolling
    @remote.on "scroll:down", => do @nextItem if @focused # and not @scrolling

    ($ "li", @scroller).bind "mouseover", (event) =>
      item = $ event.target
      @giveFocus item.index()
      @emit "item_focused", item

    @scroller.bind "mouseover", (event) => @giveFocus()
    @scroller.bind "mouseout", (event) => @releaseFocus()

  nextItem: =>
    if @last_item.nextAll("li").length
      @last_item.removeClass @selected_item_classname
      @last_item = @last_item.nextAll("li").first().addClass @selected_item_classname
      @setScrollPosition @last_item
    else
      if @config.smart_scroll
        @last_item.removeClass @selected_item_classname
        @last_item = ($ "li", @scroller).first().addClass @selected_item_classname
        @setScrollPosition @last_item
      else
        @emit "out_of_bounds", direction: "bottom"
        
    @emit "item_focused", @last_item
    @remote.playEventSound "click", 0.2, 0.3

  prevItem: =>
    if @last_item.prevAll("li").length
      @last_item.removeClass @selected_item_classname
      @last_item = @last_item.prevAll("li").first().addClass @selected_item_classname
      @setScrollPosition @last_item
    else
      if @config.smart_scroll
        @last_item.removeClass @selected_item_classname
        @last_item = ($ "li", @scroller).last().addClass @selected_item_classname
        @setScrollPosition @last_item
      else
        @emit "out_of_bounds", direction: "top"
    @emit "item_focused", @last_item
    @remote.playEventSound "click", 0.2, 0.3

  setScrollPosition: (item) =>
    if not item then throw "setScrollPosition() requires a list item."
    total_items     = item.siblings().length + 1
    item_height     = item.outerHeight()
    list_height     = item.parent().outerHeight()
    item_index      = item.index()
    viewport_height = @scroller.parent().height()
    items_in_view   = Math.floor viewport_height / item_height
    view_set        = (Math.ceil (item_index + 1) / items_in_view)
    view_set        = view_set - 1 if view_set isnt 0
    scroll_distance = "-#{view_set * viewport_height}px"
    current_pos     = @list_element.css "margin-top"

    $.keyframe.define
      name: @scroll_keyframe_name
      from: "margin-top: #{current_pos}"
      to: "margin-top: #{scroll_distance}"

    @scrolling = yes
    @list_element.playKeyframe
      name: @scroll_keyframe_name
      duration: @scroll_speed
      complete: => 
        do ($ "style##{@scroll_keyframe_name}").remove
        @scroller.removeAttr "style" # hack to support dynamic keyframe overwrite
        @scroller.css "margin-top", "#{scroll_distance}"
        @scrolling = no

  giveFocus: (index = 0)=>
    if not @locked
      @focused = yes
      @scroller.addClass @focused_area_classname
      if index
        items = ($ "li", @scroller)
        item  = items[index] or items[0]
        items.removeClass @selected_item_classname
        @last_item = ($ item).addClass @selected_item_classname if item
      else
        if @last_item then @last_item.addClass @selected_item_classname
        else @last_item = ($ "li", @scroller).first().addClass @selected_item_classname
      @selected = @last_item

  releaseFocus: =>
    @focused = no
    @scroller.removeClass @focused_area_classname
    if @last_item and not @config.leave_decoration 
      @last_item.removeClass @selected_item_classname
    else
      @last_item.removeClass @selected_item_classname
      if @selected then @last_item = @selected
      @last_item.addClass @selected_item_classname

  lock: => 
    @locked = yes
    do @releaseFocus
  
  unlock: =>
    @locked = no

  selected_item_classname: "navilist-selected"
  focused_area_classname: "navilist-focused"
  scroll_speed: 200
  scroll_keyframe_name: "navilist-scroll"

module.exports = NavigableList

###
UNTV - settings extension
Author: Gordon Hall

Enables user to configure settings API
###

jade = require "jade"
fs   = require "fs"

module.exports = (env) ->
  
  $                 = env.gui.$
  settings          = env.settings_registry.settings
  {NavigableList}   = env.gui
  {VirtualKeyboard} = env.gui
  header            = $ "header", env.view

  keyboard_config = 
    default: "alphanum"
    allow: [
      "alphanum"
      "symbols"
    ]
  keyboard = new VirtualKeyboard env.remote, keyboard_config

  ###
  Get Settings List Template and Populate
  ###
  settings_tmpl = fs.readFileSync "#{__dirname}/views/settings-list.jade"
  settings_view = jade.compile settings_tmpl
  settings_cont = $ "#settings-container ul"
  # render inside container
  settings_cont.html settings_view extensions: settings

  ###
  Initialize Navigable List
  ###
  list_config = 
    # adjust_y: header.outerHeight()
    smart_scroll: yes 
    leave_decoration: yes
  settings_menu = new NavigableList settings_cont, env.remote, list_config
  # auto give list focus
  settings_menu.giveFocus()

  ###
  Setup Event Handlers
  ###
  settings_menu.on "item_selected", (item) ->
    type      = item.attr "data-type"
    index     = item.attr "data-index"
    key       = item.attr "data-key"
    extension = settings[index]
    setting   = extension.config[key]

    # play sound
    env.remote.playEventSound "keypress"

    # filter action based on type
    switch type
      when "toggle"
        setting.toggle()
        ($ ".setting-toggle", item).attr "data-value", setting.value
      when "text"
        description = ($ "strong", item).html()
        settings_menu.lock()
        keyboard.prompt description, (text) ->
          settings_menu.unlock()
          settings_menu.giveFocus()

          # set value in ui and registry
          if text
            ($ ".value", item).html text
            setting.set text

  # Handle cycling through options
  settings_menu.on "out_of_bounds", (data) ->
    item      = settings_menu.last_item
    type      = item.attr "data-type"
    index     = item.attr "data-index"
    key       = item.attr "data-key"
    extension = settings[index]
    setting   = extension.config[key]
    first_opt = ($ ".setting-option", item).first() 
    last_opt  = ($ ".setting-option", item).last() 

    switch data.direction
      when "left"
        if (item.attr "data-type") is "options"
          setting.set(cycleOption(item, data.direction, last_opt))
      when "right"
        if (item.attr "data-type") is "options"
          setting.set(cycleOption(item, data.direction, first_opt))

  ###
  Helpers
  ###
  cycleOption = (item, direction, fallback) ->
    current  = ($ "[data-selected=true]", item)
    target   = if direction is "right" then current.next() else current.prev()
    
    current.removeAttr "data-selected"
    if target.length then target.attr "data-selected", yes
    else fallback?.attr "data-selected", yes
    # cast to number if we think we need to
    item    = ($ "[data-selected=true]", item)
    value   = item.data("value") or item.text()
    num_val = Number value 
    value   = Number(value) unless Number.isNaN(num_val)

    return value


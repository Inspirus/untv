###
UNTV - settings-registry.coffee
Author: Gordon Hall

Provides an api for configuring extensions
###

localStorage = window.localStorage
extend       = require "node.extend"

class Setting
  constructor: (key, spec) ->
    @is_toggle   = spec.is_toggle or no 
    @default     = if @is_toggle then Boolean spec.default else spec.default
    @options     = spec.options or []
    @description = spec.description or key
    # set the default value
    do @set

  toggle: =>
    if @is_toggle then @set !@value
    else throw new TypeError "Setting is not a toggle"

  set: (value) =>

    if typeof value is "undefined" or value is null
      if @persistence_key
        localStorage.setItem @persistence_key, JSON.stringify value: @default
      return @value = @default

    item = value: null

    if not @is_toggle and value not in @options and "*" not in @options
      # check for pretty name - value format
      valid = no
      @options.forEach (opt) -> 
        if value is opt.value
          valid = yes
          item  = opt
      if not valid then throw new Error "'#{value}' is not a valid option"
    
    if @persistence_key
      localStorage.setItem @persistence_key, JSON.stringify value: value

    return @value = item.value or value

  persistTo: (key) ->
    if key then @persistence_key = key

class SettingsRegistry
  constructor: (@namespace) ->
    if not @namespace then throw new Error """
      SettingsRegistry must be instantiated with a storage namespace
    """
    @settings    = []
    @used_names  = []
    @stored_keys = []

  register: (extension) =>
    entry = {}
    # parses the extension configuration
    if not extension then throw new TypeError """
      Cannot register an undefined extension
    """
    extension.config = {} unless typeof extension.config is "object"
    # enumerate configuration properies, initializing ones we need to
    for key, spec of extension.config
      if spec.register is on
        entry[key] = new Setting(key, spec)
        # check persistent storage for a value to set
        extension_key = @_createKey extension.name
        storage_key   = "#{@namespace}:#{extension_key}:#{key}"
        # track the items we have stored so we can reset this instances
        # default settings without clobbering other instances
        @stored_keys.push storage_key
        # set the value and persist it
        entry[key].persistTo storage_key
        # get serialized value
        stored_value = localStorage.getItem storage_key
        entry[key].set (JSON.parse stored_value)?.value

    settings =
      name: extension.name
      config: entry

    # push the setting instance to the resgistry
    @settings.push settings
    @update extension

  update: (extension) =>
    name = extension.name
    settings = null

    for ext in @settings
      if ext.name is name then settings = ext

    if settings
      for key of extension.config
        setting = settings.config[key]
        if setting instanceof Setting
          extension.config[key] = setting.value

  _createKey: (name) =>
    name = name.toLowerCase().replace(/\s+/g, "_")
    # if name in @used_names then return @_createKey "_#{name}"
    # @used_names.push name
    return name

  resetDefaults: =>
    localStorage.removeItem key for key in @stored_keys


module.exports = { SettingsRegistry, Setting }

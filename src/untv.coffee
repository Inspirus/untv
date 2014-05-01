###
UNTV - untv.coffee
Author: Gordon Hall

Initializes application
###

fs         = require "fs"
{$}        = require "./lib/gui-kit"
Notifier   = require "./lib/notifier"
GlobalMenu = require "./lib/global-menu"
Player     = require "./lib/player"
Remote     = require "./lib/remote"
config     = JSON.parse fs.readFileSync "#{__dirname}/config.json"
win        = global.window.nwDispatcher.requireNwGui()?.Window.get()
jade       = require "jade"
actions    = require "./lib/menu-actions"

###
Setup Remote, Global Menu, and Player
###
remote   = new Remote config.remote_port
player   = new Player ($ "#player-container"), remote
menu     = new GlobalMenu ($ "#menu-container"), remote, player
notifier = new Notifier ($ "#notifier-container"), menu, remote

# give the player the notifier instance
player.notifier = notifier

###
Register Remote Control Server
###
remote.listen ->
  console.log "remote listening on port #{config.remote_port}"

###
Load Extensions
###
bundled_ext_path  = "#{__dirname}/extensions"
bundled_ext_dir   = fs.readdirSync bundled_ext_path
# User's Home Directory
home_environment  = if process.platform is "win32" then "USERPROFILE" else "HOME"
home_dir          = process.env[home_environment]
installed_ext_dir = "#{home_dir}/.untv/extensions"

getExtensionInstallTarget = ->
  if not fs.existsSync "#{home_dir}/.untv"
    fs.mkdirSync "#{home_dir}/.untv"
    fs.mkdirSync installed_ext_dir
  fs.readdirSync installed_ext_dir

checkExtension = (path) ->
  stats = fs.statSync path
  if stats.isDirectory()
    # check for manifest file and parse it
    if fs.existsSync "#{path}/manifest.json"
      return manifest = JSON.parse fs.readFileSync "#{path}/manifest.json"
  null

registerExtension = (path) ->
  manifest = checkExtension path
  if not manifest then return
  console.log "registered extension: #{manifest.name}"
  # register extension with menu
  menu.addExtension path, manifest

# Register Bundled Extensions
for directory, index in bundled_ext_dir
  registerExtension "#{bundled_ext_path}/#{directory}"

# Register Third Party Extensions
if config.load_third_party_extensions
  for directory, index in do getExtensionInstallTarget
    registerExtension "#{installed_ext_dir}/#{directory}"

# Register "Actions"
menu.addAction action for action in actions

# show user interface
do ($ "#init-loader").hide
do menu.open
do win?.show

# help notifications
showHelp = ->
  view    = jade.compile fs.readFileSync "#{__dirname}/views/connect-remote.jade"
  content = view
    remote_ip: remote.interfaces()[0]?.address
    remote_port: config.remote_port
  notifier.notify "Welcome to UnTV", content

window.Mousetrap.bind "?", showHelp
window.Mousetrap.bind "ctrl+f", -> win.toggleKioskMode()

setTimeout ->
  if config.show_remote_instructions
    if not remote.connected then showHelp()
    remote.on "remote:connected", ->
      do notifier.dismiss
      notifier.notify "Remote", "Connected!", yes

, 1000

module.exports = menu

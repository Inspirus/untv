###
UNTV - menu-actions.coffee
Author: Gordon Hall

Non-extension actions to add to global menu
###

gui = global.window.nwDispatcher.requireNwGui()

module.exports = [

  # Toggles Fullscreen Mode
  {
    name: "Toggle Fullscreen"
    icon: "assets/images/icons/screen.svg"
    list_priority: 9998
    description: "Toggle Between Window Mode and Fullscreen"
    handler: ->
      win = gui.Window.get()
      win.toggleKioskMode()
  }

  # Quits UNTV
  {
    name: "Quit"
    icon: "assets/images/icons/quit.svg"
    list_priority: 9999
    description: "Close and Return to Operating System"
    handler: ->
      win = gui.Window.get()
      win?.close()
  }

]

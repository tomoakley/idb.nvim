#idb.nvim
I am attempting to write a Neovim plugin that can use [idb](https://fbidb.io/), a tool to interact with iOS simulators (mainly for automated testing) in a scriptable manor. I want to be able to show a telescope.nvim search box with all the interactable elements on the iOS simulator screen, so I can avoid using the mouse when interacting with the simulator.

## Install

Use your standard plugin manager (however there is very little here so far so not much point).

## Dependencies
- [idb](https://github.com/facebook/idb) (needs Python 3)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim/tree/master)

## Setup
```
require("nvim-idb").setup()
```

## Usage
```
:lua require('telescope').extensions["nvim-idb"].get_elements()
```
This will probably not work correctly! But if you want to try it then go ahead.nvim

`:IDBStartSession` - This is a _very_ experimental mode to start an IDB "session". This will "take over" your vim session; it will remap various keys to manipulate the simulator:
- `j` - scroll down on simulator
- `k` - scroll up on simulator
- `f` - show element picker in Telescope
- `t` - tap on specifc point. Pass in `x y` with a space or a comma. E.g `650,2600`, `650, 2600` or `650 2600` should all work
- `r` - restart app
- `<esc>` - Quit this mode and return mappings to vim

I think this could be pretty powerful. I have some ideas on other mappings or features (most of which already exist in vim!) I could add:
- [ ] `gg` and `G` to scroll to top/bottom of content in the simulator
- [ ] `.` to repeat the last command
- [ ] `u` to swipe back on the simulator (or other actions to undo your last action)
- [ ] `10j` - bigger motion events
- [ ] - record and play macros (?!) - record a sequence of events in the Simulator and then play it back later (persisted across IDB sessions of course!)
- [ ] `/` - search for item on screen and scroll to it

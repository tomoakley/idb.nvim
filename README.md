# idb.nvim
I am attempting to write a Neovim plugin that can use [idb](https://fbidb.io/), a tool to interact with iOS simulators (mainly for automated testing) in a scriptable manor. I want to be able to show a telescope.nvim search box with all the interactable elements on the iOS simulator screen, so I can avoid using the mouse when interacting with the simulator.

## Install

Use your standard plugin manager (however there is very little here so far so not much point).

## Dependencies
- [idb](https://github.com/facebook/idb) (needs Python 3)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim/tree/master)

### Plugin structure

```
.
├── lua
│   ├── plugin_name
│   │   └── module.lua
│   └── plugin_name.lua
├── Makefile
├── plugin
│   └── plugin_name.lua
├── README.md
├── tests
│   ├── minimal_init.lua
│   └── plugin_name
│       └── plugin_name_spec.lua
```

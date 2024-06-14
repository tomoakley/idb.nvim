vim.api.nvim_create_user_command("IDBRestartCurrentApp", require("nvim-idb.idb").restartCurrentApp, {})
vim.api.nvim_create_user_command("IDBStartSession", require("nvim-idb.idb").startSession, {})


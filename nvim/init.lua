require("config.lazy")
vim.api.nvim_create_autocmd("VimEnter", { callback = function()
    if require("lazy.status").has_updates then
        require("lazy").update({ show = false })
    end
end })

vim.g.catppuccin_flavour = "mocha" -- latte, frappe, macchiato, mocha

local telescope = require("telescope")
local telescope_actions = require("telescope.actions")

telescope.load_extension("fzf")
telescope.setup({
    defaults = {
        mappings = {
            i = {
                ["<Esc>"] = telescope_actions.close,
            }
        }
    }

})

require("oil").setup({
    cleanup_delay_ms = false,
    keymaps = {
        ["g?"] = { "actions.show_help", mode = "n" },
        ["<CR>"] = "actions.select",
        -- these are defaults I disabled; leaving commented to consider
        -- later
        -- ["<C-s>"] = { "actions.select", opts = { vertical = true } },
        -- ["<C-h>"] = { "actions.select", opts = { horizontal = true } },
        -- ["<C-t>"] = { "actions.select", opts = { tab = true } },
        -- ["<C-p>"] = "actions.preview",
        ["<C-c>"] = { "actions.close", mode = "n" },
        ["<C-l>"] = "actions.refresh",
        ["<BS>"] = { "actions.parent", mode = "n" },
        ["_"] = { "actions.open_cwd", mode = "n" },
        ["`"] = { "actions.cd", mode = "n" },
        ["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
        ["gs"] = { "actions.change_sort", mode = "n" },
        ["gx"] = "actions.open_external",
        ["g."] = { "actions.toggle_hidden", mode = "n" },
        ["g\\"] = { "actions.toggle_trash", mode = "n" },
    },
    use_default_keymaps = false,
    view_options = {
        show_hidden = true,
        is_always_hidden = function(name)
            return name:find("^%.%.$") ~= nil
        end,
    },
})

local gitsigns = require("gitsigns")
gitsigns.setup({
    signcolumn = false,
    numhl = true,

    on_attach = function(bufnr)
        local gitsigns = require("gitsigns")

        -- so that the current branch is immediately reflected in the status line
        vim.cmd.redrawstatus()

        local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
        end

        -- Actions
        map("v", "<Leader>hs", function()
            gitsigns.stage_hunk { vim.fn.line("."), vim.fn.line("v") }
        end)
        map("v", "<Leader>hr", function()
            gitsigns.reset_hunk { vim.fn.line("."), vim.fn.line("v") }
        end)

        -- Text object
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>")
    end
})

local gitops = require("gitops")

require("lsp-config")

local treesitter_languages = {
    "c",
    "cpp",
    "bash",
    "make",
    "rust",
    "python",
    "lua",
    "vimdoc",
    "markdown",
    "brightscript",
    "typst",
}
require("nvim-treesitter").install(treesitter_languages)
vim.api.nvim_create_autocmd("FileType", {
    pattern = treesitter_languages,
    callback = function()
        vim.treesitter.start() -- syntax highlighting, provided by Neovim

        -- folds, provided by Neovim
        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.wo.foldmethod = "expr"

        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" -- indentation, provided by nvim-treesitter
    end,
})

vim.filetype.add({
    extension = {
        brs = "brightscript",
    }
})

vim.cmd.colorscheme("custom")

-- define this in WSL so clipboard is set correcty
-- needed to fix startup performance issue
if os.getenv("IS_WSL") then
    -- taken from mzr1996's comment on https://github.com/neovim/neovim/issues/9570
    vim.cmd [[
      let g:clipboard = {
      \ 'name': 'win32yank',
      \ 'copy': {
      \    '+': 'win32yank.exe -i --crlf',
      \    '*': 'win32yank.exe -i --crlf',
      \  },
      \ 'paste': {
      \    '+': 'win32yank.exe -o --lf',
      \    '*': 'win32yank.exe -o --lf',
      \ },
      \ 'cache_enabled': 0,
      \ }
    ]]
end

vim.cmd("set clipboard+=unnamedplus")

-- options
vim.o.autowrite = true
vim.o.autowriteall = true
vim.o.cmdheight = 0 -- if removing, search for 'cmdheight' to see things that relate
                    -- and might have to be changed
-- vim.o.colorcolumn = '80'
vim.o.diffopt = "internal,filler,closeoff,linematch:40,foldcolumn:0,vertical"
vim.o.expandtab = true
vim.o.fillchars = "diff: "
vim.o.foldlevel = 9999
vim.o.fsync = false
vim.o.hlsearch = false
vim.o.number = true
vim.o.relativenumber = true
vim.o.scrolloff = 9999 -- keep cursor vertically centered
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
vim.o.spelllang = "en_us"
vim.o.splitright = true
vim.o.tabstop = 4
vim.o.textwidth = 100 -- use this as a default for all files
vim.o.tildeop = true
vim.o.updatetime = 100
vim.o.wrap = false
vim.o.statusline = "%!v:lua.statusline()"

local dap = require("dap")

-- must be global to be callable from vimscript
statusline = function()
    local window_id = vim.g.statusline_winid
    local buffer_id = vim.api.nvim_win_get_buf(window_id)

    -- results that contain % must be escaped since % statusline items will be expanded
    local escape = function(s)
        return s:gsub("%%", "%%")
    end

    local git_head = vim.b[buffer_id].gitsigns_head
    local git_head_component = ""
    if git_head then
        git_head_component = "%#Normal#::" .. "%#GitBranch#" .. escape(git_head) .. "%#Normal#::"
    end

    local cwd_component = "%#Directory#" .. escape(vim.fn.fnamemodify(vim.fn.getcwd(), ":~"))
    if git_head_component == "" then
        cwd_component = cwd_component .. "/"
    end

    local buffer_name = vim.api.nvim_buf_get_name(buffer_id)

    local file_path_absolute
    local oil_base = buffer_name:match("^oil://(.*)")
    if oil_base then
        file_path_absolute = oil_base
    else
        file_path_absolute = vim.fn.fnamemodify(buffer_name, ":~")
    end

    local file_path_short = vim.fn.fnamemodify(file_path_absolute, ":.")
    local file_component
    if vim.fs.normalize(file_path_short) == vim.fs.normalize(cwd_component) then
        file_component = ""
    else
        file_component = "%#Normal#" .. escape(file_path_short)
    end

    return cwd_component
        .. git_head_component
        .. file_component
        .. " %#Normal#%r"
        .. " " .. dap.status()
end

vim.diagnostic.config({
    virtual_text = {
        severity = { min = vim.diagnostic.severity.INFO },
    },
    signs = false,
})

local telescope_action_state = require("telescope.actions.state")

local telescope_pickers = require("telescope.pickers")
local telescope_finders = require("telescope.finders")
local telescope_config = require("telescope.config").values
local telescope_builtin = require("telescope.builtin")

-- keymaps, sorted by their position on the keyboard, first by row then by column

-- I don't generally add keymaps in on_attach functions because I don't like to
-- use keys for other things when the plugin/lsp/whatever isn't attached

vim.g.mapleader = " "

-- telescope picker to change directory
-- needs to be global so it can be called on startup (see awesome rc.lua)
pick_directory = function(opts)
    opts = opts or {}
    local home_directory = os.getenv("HOME")
    telescope_pickers.new(opts, {
        prompt_title = "Change Directory",
        finder = telescope_finders.new_oneshot_job({
            "find",
            home_directory,
            "-maxdepth",
            "1", "-mindepth",
            "1", "-type", "d",
            "-printf",
            "%f\\n",
        }, {}),
        sorter = telescope_config.file_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            telescope_actions.select_default:replace(function()
                telescope_actions.close(prompt_bufnr)
                vim.cmd("cd "
                    .. home_directory
                    .. "/"
                    .. telescope_action_state.get_selected_entry()[1]
                )
                telescope_builtin.find_files()
            end)
            return true
        end,
    }):find()
end

-- needs to be global so it can be called on startup (see awesome rc.lua)
pick_file = function()
    telescope_builtin.find_files()
end

dap.adapters["lldb"] = {
    type = "executable",
    command = "lldb-dap",
}

dap.adapters.gdb = {
    type = "executable",
    command = "gdb",
    args = { "--interpreter=dap" },
}

local is_absolute_path = function(path)
    if vim.fn.has("win32") == 1 then
        return path:match("^%a+:[/\\]")
    else
        return path:find("^/")
    end
end

local absolute_path_relative_to = function(path, relative_to)
    path = vim.fs.normalize(path)
    if is_absolute_path(path) then
        return path
    else
        -- path is a relative path
        return vim.fs.joinpath(relative_to, path)
    end
end

-- returns the project config and the absolute path to the directory containing the config
local get_project_config = function()
    local config_file = vim.fs.find(".de-config.lua", {
        upward = true,
        path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
    })
    if config_file[1] then
        return dofile(config_file[1]), vim.fs.dirname(config_file[1])
    end
end

local debug_run = function()
    local project_config, directory = get_project_config()
    assert(project_config, "no project config found")
    local debug_config = project_config.debug
    assert(debug_config, "no debug config found")
    -- assert(type(debug_config.type) = "string", ) -- TODO consider asserting
    local config = {
        request = "launch",
        name = "",
    }

    for key, value in pairs(debug_config) do
        config[key] = value
    end

    if config.program then
        config.program = absolute_path_relative_to(config.program, directory)
    end

    dap.run(config)
end

-- normal mode keymaps
for _, map in ipairs({
    { "^", "^9999zh" },
    { "gr", vim.lsp.buf.references },
    { "gi", vim.lsp.buf.implementation },
    { "gd", vim.lsp.buf.definition },
    { "gD", vim.lsp.buf.declaration },
    { "K", vim.lsp.buf.hover },
    { "[d", vim.diagnostic.goto_prev },
    { "]d", vim.diagnostic.goto_next },

    { "<C-p>", telescope_builtin.find_files },
    { "<C-j>", "<C-w>j" },
    { "<C-l>", "<C-w>l" },
    { "<C-t>", pick_directory },
    { "<C-n>", ":silent cn<cr>" },
    { "<C-e>", ":silent cp<cr>" },
    { "<C-c>", function()
        vim.o.termguicolors = not vim.o.termguicolors
        if vim.o.termguicolors then
            print("enabled terminal gui colors")
        else
            print("disabled terminal gui colors")
        end
    end },
    { "<C-k>", "<C-w>k" },
    { "<C-h>", "<C-w>h" },
    { "<C-.>", function()
        if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
        else
            gitsigns.nav_hunk("next")
        end
    end },
    { "<C-/>", function()
        if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
        else
            gitsigns.nav_hunk("prev")
        end
    end },

    { "<C-Down>", dap.step_over },
    { "<C-Up>", dap.step_out },

    { "<Leader>q", vim.diagnostic.setloclist },
    { "<Leader>wl", function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end },
    { "<Leader>wa", vim.lsp.buf.add_workspace_folder },
    { "<Leader>wr", vim.lsp.buf.remove_workspace_folder },
    { "<Leader>f", function()
        local view = vim.fn.winsaveview()
        vim.cmd("keepjumps normal! gggqG")
        vim.fn.winrestview(view)
    end },
    { "<Leader>p", dap.toggle_breakpoint },
    -- see below for <Leader>b mapping
    { "<Leader>j", "!$jq<cr>" },
    { "<Leader>a", function()
        telescope_builtin.buffers({
            ignore_current_buffer = true,
            sort_mru = true,
        })
    end },
    { "<Leader>r", ":grep '\\b(<C-r><C-w>)\\b'<cr>" },
    { "<Leader>t", function() -- run t.sh
        -- TODO figure out how to control whether to debug or use t.sh
        debug_run()

        --[[
        terminal_command = "te de; shopt -s expand_aliases; . t.sh"

        vim.cmd("wa")

        tsh_window_number = vim.fn.bufwinnr("t.sh")
        if tsh_window_number ~= -1 then
            vim.cmd("norm " .. tsh_window_number .. " <C-W><C-W>")
            vim.cmd(terminal_command)
        else
            vim.cmd("vs +" .. string.gsub(terminal_command, " ", "\\ "))
        end
        ]]
    end },
    { "<Leader>g", ":Git " },
    { "<Leader>n", ":vs t.sh<cr>" },
    { "<Leader>e", vim.diagnostic.open_float },
    { "<Leader>i", ":grep -i '\\b(<C-r><C-w>)\\b'<cr>" },
    { "<Leader>z", function() -- quit unless last window
        if (#vim.api.nvim_tabpage_list_wins(0)) > 1 then
            vim.cmd("q")
        end
    end },
    { "<Leader>ca", vim.lsp.buf.code_action },
    { "<Leader>co", function()
        local colorschemes = {
            "custom",
            "catppuccin-mocha",
        }
        local current_scheme_index = nil
        for index, scheme in ipairs(colorschemes) do
            if vim.g.colors_name == scheme then
                current_scheme_index = index
                break
            end
        end

        local next_scheme_index
        if current_scheme_index ~= nil then
            next_scheme_index = current_scheme_index + 1
            if (next_scheme_index > #colorschemes) then
                next_scheme_index = 1
            end
        else
            next_scheme_index = 1
        end

        vim.cmd.colorscheme(colorschemes[next_scheme_index])
    end },
    { "<Leader>d", function() vim.cmd.edit({ vim.fn.expand("%:p:h") }) end },
    { "<Leader>D", vim.lsp.buf.type_definition },
    { "<Leader>hp", gitsigns.preview_hunk },
    { "<Leader>hb", function() gitsigns.blame_line({ full = true }) end },
    { "<Leader>hq", function()
        gitsigns.setqflist("all", { open = false })
        vim.cmd.crewind()
    end },
    { "<Leader>hr", gitsigns.reset_hunk },
    { "<Leader>hR", gitsigns.reset_buffer },
    { "<Leader>hs", gitsigns.stage_hunk },
    { "<Leader>hS", gitsigns.stage_buffer },
    { "<Leader>hd", function() gitsigns.diffthis(nil, { split = "belowright" }) end },
    { "<Leader>hD", function() gitsigns.diffthis("~", { split = "belowright" }) end },
    { "<Leader>.", function()
        vim.cmd.wa()
        vim.cmd.source(vim.fn.stdpath("config") .. "/init.lua")
    end },
}) do
    vim.keymap.set("n", map[1], map[2])
end

vim.keymap.set("ca", "H", "vert h")
vim.keymap.set({ "n", "v" }, "<Leader>b", gitops.show_current_line_commit)

vim.api.nvim_create_user_command(
    "View",
    function(args)
        gitops.show_commit(args.args)
    end,
    { nargs = 1 }
)

-- make all marks global marks (and the same capital and lowercase)
for uppercase_ascii=65,90 do
    local char_uppercase = string.char(uppercase_ascii)
    local char_lowercase = string.char(uppercase_ascii + 32)
    vim.keymap.set("n", "m" .. char_lowercase, "m" .. char_uppercase)
    vim.keymap.set("n", "'" .. char_lowercase, "'" .. char_uppercase)
end

for _, autocommand in ipairs({
    { "TermOpen", "*", function()
        vim.keymap.set("t", "<Esc>", "<c-\\><c-n>", { buffer = true })
        vim.wo.listchars = ""
        vim.wo.number = false
        vim.wo.relativenumber = false
        vim.cmd.startinsert()
    end },

    { "FileType", "gitcommit,text,markdown", function() vim.o.spell = true end },

    -- many ftplugins set these but I don't want them
    { "FileType", "*", function()
        vim.opt.formatoptions:remove("r")
        vim.opt.formatoptions:remove("o")
    end },

    { "RecordingEnter", "*", function() vim.o.cmdheight = 1 end },
    { "RecordingLeave", "*", function() vim.o.cmdheight = 0 end },

    -- errors need to be skipped so that there is no error message for buffers
    -- without a file name
    { "FocusLost", "*", function() vim.cmd("silent! wa") end },
    { "VimSuspend", "*", function() vim.cmd("silent! wa") end },
}) do
    vim.api.nvim_create_autocmd(autocommand[1], {
        pattern = autocommand[2],
        callback = autocommand[3],
    })
end

vim.api.nvim_create_autocmd("User", {
    pattern = "DapProgressUpdate",
    command = "redrawstatus"
})

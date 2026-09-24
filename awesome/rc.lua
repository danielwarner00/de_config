-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({
        preset = naughty.config.presets.critical,
        title = "Oops, there were errors during startup!",
        text = awesome.startup_errors,
    })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function(err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({
            preset = naughty.config.presets.critical,
            title = "Oops, an error happened!",
            text = tostring(err),
        })
        in_error = false
    end)
end
-- }}}

local debug_log = function(text)
    naughty.notify({
        preset = naughty.config.presets.info,
        title = "debug",
        text = text,
    })
end

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
beautiful.init(gears.filesystem.get_configuration_dir() .. "theme.lua")

local spawn_shell = function(properties)
    awful.spawn("kitty --single-instance --class Shell", properties)
end
local is_shell = function(c)
    return c.class == "Shell"
end

local spawn_editor = function(properties, directory)
    local command = { "kitty", "--single-instance", "--class", "Editor" }
    if directory then
        table.insert(command, "--directory")
        table.insert(command, directory)
    end
    local editor = os.getenv("EDITOR")
    if editor then
        table.insert(command, editor)
    else
        table.insert(command, "nvim")
        if directory then
            table.insert(command, "-c")
            table.insert(command, "lua pick_file()")
        else
            table.insert(command, "-c")
            table.insert(command, "lua pick_directory()")
        end
    end
    awful.spawn(command, properties)
end
local is_editor = function(c)
    return c.class == "Editor"
end

-- can't set google chrome's class so have to store the client instead
local email_client = nil
local spawn_email = function(properties)
    -- workaround to implement a callback since Google Chrome does not play nicely in X :(
    local callback
    callback = function(c)
        email_client = c
        client.disconnect_signal("manage", callback)
    end
    client.connect_signal("manage", callback)
    awful.spawn("google-chrome-stable --new-window https://mail.google.com/mail/u/0/#inbox", properties)
end
local is_email = function(c)
    return c == email_client
end

local spawn_browser = function(properties)
    awful.spawn("google-chrome-stable", properties)
end
local is_browser = function(c)
    return c.class == "Google-chrome" and c ~= email_client
end

local is_other = function(c)
    return not is_shell(c)
        and not is_browser(c)
        and not is_editor(c)
        and not is_email(c)
end

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
    -- awful.layout.suit.floating,
    -- awful.layout.suit.tile,
    -- awful.layout.suit.tile.left,
    -- awful.layout.suit.tile.bottom,
    -- awful.layout.suit.tile.top,
    -- awful.layout.suit.fair,
    -- awful.layout.suit.fair.horizontal,
    -- awful.layout.suit.spiral,
    awful.layout.suit.max,
    awful.layout.suit.spiral.dwindle,
    -- awful.layout.suit.max.fullscreen,
    -- awful.layout.suit.magnifier,
    -- awful.layout.suit.corner.nw,
    -- awful.layout.suit.corner.ne,
    -- awful.layout.suit.corner.sw,
    -- awful.layout.suit.corner.se,
}
-- }}}

local function set_wallpaper()
    gears.wallpaper.set("#1e1e2e") -- catppuccin mocha Base
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

-- invariants that are maintained (except for transient state)
--     - all clients have one tag
--     - when one client is visible the fullscreen tag is active
--     - one or zero tags are selected

local fullscreen_tag = awful.tag.add("fullscreen", {
    screen = screen.primary,
    layout = awful.layout.suit.max,
})
fullscreen_tag:view_only()

launch_editor_in_directory = function(directory)
    spawn_editor({ tag = fullscreen_tag }, directory)
    fullscreen_tag:view_only()
end

awful.screen.connect_for_each_screen(function(s)
    set_wallpaper()
end)

local done_callback

local myprompt = awful.widget.prompt({
    prompt = 'Run: ',
    done_callback = function()
        done_callback()
    end
})

local popup = awful.popup({
    widget = myprompt,
    ontop        = true,
    placement    = awful.placement.centered,
    shape        = gears.shape.rectangle,
    visible = false,
})

done_callback = function()
    popup.visible = false
end

local run_prompt = function()
    popup.visible = true
    myprompt:run()
end

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({}, 4, awful.tag.viewnext),
    awful.button({}, 5, awful.tag.viewprev)
))
-- }}}

local cycling = false
local get_clients_by_most_recent_focus
local update_current_focus_time
do
    local client_last_focused_time = {}
    
    client.connect_signal("focus", function(c)
        if not cycling then
            client_last_focused_time[c] = os.time()
        end
    end)

    client.connect_signal("unmanage", function(c)
        client_last_focused_time[c] = nil
    end)

    get_clients_by_most_recent_focus = function(filter)
        local result = {}

        for _, c in ipairs(client.get()) do
            if not filter or filter(c) then
                table.insert(result, c)
            end
        end

        table.sort(result, function(left, right)
            return (client_last_focused_time[left] or 0) > (client_last_focused_time[right] or 0)
        end)

        return result
    end

    update_current_focus_time = function()
        if client.focus then
            client_last_focused_time[client.focus] = os.time()
        end
    end
end

local establish_multiple_tag = function()
    local multiple_tag

    if client.focus.first_tag == fullscreen_tag then
        multiple_tag = awful.tag.add("multiple", {
            screen = screen.primary,
            volatile = true,
            layout = awful.layout.suit.spiral.dwindle,
        })
        multiple_tag:connect_signal("untagged", function(t)
            clients = t:clients()
            if #clients == 1 then
                clients[1]:move_to_tag(fullscreen_tag)
                -- tag will be automatically deleted because it is volatile
            end
        end)

        client.focus:move_to_tag(multiple_tag)
    else
        multiple_tag = client.focus.first_tag
    end

    multiple_tag:view_only()
    return multiple_tag
end

local cycle_clients_in_history_order
local cycle_clients_in_history_order_multi
local cycle_stop_callback

-- {{{ Key bindings
globalkeys = gears.table.join(
    awful.key(
        { modkey },
        "k",
        hotkeys_popup.show_help,
        { description="show help", group="awesome" }
    ),
    awful.key(
        { modkey },
        "c",
        function()
            if client.focus then
                client.focus:kill()
            end
        end,
        { description = "close", group = "client" }
    ),
    awful.key(
        { modkey },
        "p",
        function()
            spawn_shell({ tag = fullscreen_tag })
            fullscreen_tag:view_only()
        end,
        { description = "Create shell", group = "client" }
    ),
    awful.key(
        { modkey },
        "f",
        function()
            spawn_browser({ tag = fullscreen_tag })
            fullscreen_tag:view_only()
        end,
        { description = "Create browser", group = "client" }
    ),
    awful.key(
        { modkey },
        "q",
        function()
            spawn_editor({ tag = fullscreen_tag })
            fullscreen_tag:view_only()
        end,
        { description = "Create editor", group = "client" }
    ),
    awful.key(
        { modkey, "Mod1" },
        "p",
        function()
            spawn_shell({ tag = establish_multiple_tag() })
        end,
        { description = "Create shell in multiview", group = "client" }
    ),
    awful.key(
        { modkey, "Mod1" },
        "f",
        function()
            spawn_browser({ tag = establish_multiple_tag() })
        end,
        { description = "Create browser in multiview", group = "client" }
    ),
    awful.key(
        { modkey, "Mod1" },
        "q",
        function()
            spawn_editor({ tag = establish_multiple_tag() })
        end,
        { description = "Create editor in multiview", group = "client" }
    ),
    awful.key(
        { modkey },
        "`",
        function()
            for _, c in ipairs(client.get()) do
                c:move_to_tag(fullscreen_tag)
                c.maximized = false -- clients should never be maximized, but this resets it in case they do
            end
        end,
        { description = "make all clients fullscreen", group = "client" }
    ),
    awful.key(
        { modkey, "Control" },
        "r",
        awesome.restart,
        { description = "reload awesome", group = "awesome" }
    ),
    awful.key(
        { modkey, "Shift" },
        "q",
        awesome.quit,
        { description = "quit awesome", group = "awesome" }
    ),
    -- Prompt
    awful.key(
        { modkey },
        "d",
        run_prompt,
        { description = "run prompt", group = "launcher" }
    ),

    awful.key(
        { modkey },
        "x",
        function()
            awful.prompt.run {
                prompt = "Run Lua code: ",
                textbox = awful.screen.focused().mypromptbox.widget,
                exe_callback = awful.util.eval,
                history_path = awful.util.get_cache_dir() .. "/history_eval"
            }
        end,
        { description = "lua execute prompt", group = "awesome" }
    ),
    awful.key(
        { modkey },
        "t",
        function()
            cycle_clients_in_history_order(is_shell, spawn_shell)
        end,
        { description = "Cycle through shells in current context", group = "client" }
    ),
    awful.key(
        { modkey },
        "s",
        function()
            cycle_clients_in_history_order(is_browser, spawn_browser)
        end,
        { description = "Cycle through browsers in current context", group = "client" }
    ),
    awful.key(
        { modkey },
        "r",
        function()
            cycle_clients_in_history_order(is_other)
        end,
        { description = "Cycle through other clients in current context", group = "client" }
    ),
    awful.key(
        { modkey },
        "a",
        function()
            cycle_clients_in_history_order(is_editor, spawn_editor)
        end,
        { description = "Cycle through other clients in current context", group = "client" }
    ),
    awful.key(
        { modkey },
        "h",
        function()
            cycle_clients_in_history_order(is_email, spawn_email)
        end,
        { description="Go to email", group="awesome" }
    ),
    awful.key(
        { modkey, "Mod1" },
        "t",
        function()
            cycle_clients_in_history_order_multi(is_shell, spawn_shell)
        end,
        { description = "Cycle through shells in current context in multi view", group = "client" }
    ),
    awful.key(
        { modkey, "Mod1" },
        "s",
        function()
            cycle_clients_in_history_order_multi(is_browser, spawn_browser)
        end,
        { description = "Cycle through browsers in current context in multi view", group = "client" }
    ),
    awful.key(
        { modkey, "Mod1" },
        "r",
        function()
            cycle_clients_in_history_order_multi(is_other)
        end,
        { description = "Cycle through other clients in current context in multi view", group = "client" }
    ),
    awful.key(
        { modkey, "Mod1" },
        "a",
        function()
            cycle_clients_in_history_order_multi(is_editor, spawn_editor)
        end,
        { description = "Cycle through editors in current context in multi view", group = "client" }
    ),

    -- getting the release of the Mod4/Super_L key needs a workaround found on
    -- https://github.com/awesomeWM/awesome/issues/169, see psychon and timroes's comments
    -- yes the Super_L bind that does nothing is needed
    -- TODO instead of using Super_L base it off the modkey so it is correct with different modkeys
    awful.key(
        {},
        "Super_L",
        nil,
        { description = "Cycle through editors in current context in multi view", group = "client" }
    ),
    awful.key(
        { modkey },
        "Super_L",
        nil,
        function() -- called on release
            cycle_stop_callback()
        end,
        { description = "Cycle through editors in current context in multi view", group = "client" }
    ),
    awful.key(
        {},
        "XF86AudioPlay",
        function()
            awful.spawn("playerctl play-pause")
        end
    ),
    awful.key(
        {},
        "XF86AudioNext",
        function()
            awful.spawn("playerctl next")
        end
    ),
    awful.key(
        {},
        "XF86AudioPrev",
        function()
            awful.spawn("playerctl previous")
        end
    )
)

do
    local increment_index = nil
    local current_filter = nil
    local focus_order = nil

    local cycle_start = function()
        if not cycling then
            current_filter = nil
        end
        cycling = true
    end

    local get_client_in_history_order = function(filter)
        if filter ~= current_filter then
            focus_order = get_clients_by_most_recent_focus(filter)

            if #focus_order > 1 and focus_order[1] == client.focus then
                increment_index = 2
            else
                increment_index = 1
            end
            current_filter = filter
        end

        local c = nil
        if #focus_order > 0 then
            c = focus_order[increment_index]
            increment_index = increment_index + 1
            if increment_index > #focus_order then
                increment_index = 1
            end
        end

        return c
    end

    cycle_clients_in_history_order = function(filter, spawn)
        cycle_start()
        c = get_client_in_history_order(filter)
        if c then
            c:jump_to()
        elseif spawn then
            spawn()
            current_filter = nil -- this causes focus_order to be reset next time
        end
    end

    local temporary_client = nil
    local multiple_tag = nil

    cycle_clients_in_history_order_multi = function(filter, spawn)
        cycle_start()
        c = get_client_in_history_order(filter)
        if c then
            if c ~= client.focus then
                multiple_tag = establish_multiple_tag()

                if c.first_tag ~= multiple_tag then
                    c:toggle_tag(multiple_tag)
                end
                if temporary_client then
                    temporary_client:toggle_tag(multiple_tag)
                end
                temporary_client = c

                c:jump_to()
            end
        elseif spawn then
            multiple_tag = establish_multiple_tag()
            spawn({ tag = multiple_tag })
            current_filter = nil -- this causes focus_order to be reset next time
        end
    end

    cycle_stop_callback = function()
        if temporary_client then
            temporary_client:move_to_tag(multiple_tag)
        end
        temporary_client = nil
        multiple_tag = nil

        cycling = false
        update_current_focus_time()
    end
end

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        -- View tag only.
        awful.key(
            { modkey },
            "#" .. i + 9,
            function()
                local screen = awful.screen.focused()
                local tag = screen.tags[i]
                if tag then
                   tag:view_only()
                end
            end,
            { description = "view tag #"..i, group = "tag" }
        ),
        -- Toggle tag display.
        awful.key(
            { modkey, "Control" },
            "#" .. i + 9,
            function()
                local screen = awful.screen.focused()
                local tag = screen.tags[i]
                if tag then
                   awful.tag.viewtoggle(tag)
                end
            end,
            { description = "toggle tag #" .. i, group = "tag" }
        ),
        -- Move client to tag.
        awful.key(
            { modkey, "Shift" },
            "#" .. i + 9,
            function()
                if client.focus then
                    local tag = client.focus.screen.tags[i]
                    if tag then
                        client.focus:move_to_tag(tag)
                        tag:view_only()
                    end
                end
            end,
            { description = "move focused client to tag #"..i, group = "tag" }
        ),
        -- Toggle tag on focused client.
        awful.key(
            { modkey, "Control", "Shift" },
            "#" .. i + 9,
            function()
                if client.focus then
                    local tag = client.focus.screen.tags[i]
                    if tag then
                        client.focus:toggle_tag(tag)
                    end
                end
            end,
            { description = "toggle focused client on tag #" .. i, group = "tag" }
        )
    )
end

clientbuttons = gears.table.join(
    awful.button({}, 1, function(c)
        c:emit_signal("request::activate", "mouse_click", { raise = true })
    end),
    awful.button({ modkey }, 1, function(c)
        c:emit_signal("request::activate", "mouse_click", { raise = true })
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function(c)
        c:emit_signal("request::activate", "mouse_click", { raise = true })
        awful.mouse.client.resize(c)
    end)
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    {
        rule = {},
        properties = {
            focus = awful.client.focus.filter,
            raise = true,
            buttons = clientbuttons,
            screen = awful.screen.preferred,
            placement = awful.placement.no_overlap+awful.placement.no_offscreen,
        },
    },

    -- Floating clients.
    {
        rule_any = {
            instance = {
                "DTA",  -- Firefox addon DownThemAll.
                "copyq",  -- Includes session name in class.
                "pinentry",
            },
            class = {
                "Arandr",
                "Blueman-manager",
                "Gpick",
                "Kruler",
                "MessageWin", -- kalarm.
                "Sxiv",
                "Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
                "Wpa_gui",
                "veromix",
                "xtightvncviewer"
            },

            -- Note that the name property shown in xprop might be set slightly after creation of the client
            -- and the name shown there might not match defined rules here.
            name = {
                "Event Tester", -- xev.
            },
            role = {
                "AlarmWindow", -- Thunderbird's calendar.
                "ConfigManager", -- Thunderbird's about:config.
                "pop-up", -- e.g. Google Chrome's (detached) Developer Tools.
            },
        }, 
        properties = { floating = true },
    },

    -- Set Firefox to always map on the tag named "2" on screen 1.
    -- { rule = { class = "Firefox" },
    --   properties = { screen = 1, tag = "2" } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function(c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup
        and not c.size_hints.user_position
        and not c.size_hints.program_position
    then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", { raise = false })
end)

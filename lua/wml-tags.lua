local helper = wesnoth.require "lua/helper.lua"
local T = helper.set_wml_tag_metatable {}
local _ = wesnoth.textdomain "wesnoth-Grnk"

function wesnoth.wml_actions.dialog_message(cfg)
    -- Set up tag [dialog_message]
    -- Displays centered, framed, clickable message
    -- Only key: message

    local message=(cfg.message)

    local dialog = {
        T.tooltip { id = "tooltip_large" },
        T.helptip { id = "tooltip_large" },
        T.grid {
            T.row { T.column { horizontal_alignment = "left",
                border = "all",
                border_size = 5,
                T.label { label = message } } }
        },
        click_dismiss = true
    }

    wesnoth.delay(20)
    wesnoth.show_dialog(dialog)
end

function wesnoth.wml_actions.dialog_defeat(cfg)
    -- Set up tag [dialog_defeat]
    -- Displays defeat message, but with text given by
    -- key 'message'

    local message=(cfg.message)

    local dialog = {
        T.tooltip { id = "tooltip_large" },
        T.helptip { id = "tooltip_large" },
        T.grid {
            T.row { T.column { horizontal_alignment = "left",
                grow_factor = 1, -- this one makes the title bigger and golden
                border = "all",
                border_size = 5,
                T.label { definition = "title", label = "Defeat" } } },
            T.row { T.column { horizontal_alignment = "left",
                border = "all",
                border_size = 5,
                T.label { label = message } } }
        },
        click_dismiss = true
    }

    wesnoth.delay(20)
    wesnoth.show_dialog(dialog)
end

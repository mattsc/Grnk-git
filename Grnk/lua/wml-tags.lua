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

function wesnoth.wml_actions.adjust_facing(cfg)
    -- Set up tag [adjust_facing]
    -- Adjust the facing of two units to face each other (such as before a dialog).
    -- Units are identified by id= and second_id= keys.
    -- I don't care about making this more general at this time, but that's easy to do.
    -- speaker_only=true can be set to only change the facing of the speaker

    -- The following is my code from ai_helper; don't want to include all of ai_helper here
    local function cartesian_coords(x, y)
        -- Converts coordinates from hex geometry to cartesian coordinates,
        -- meaning that y coordinates are offset by 0.5 every other hex
        -- Example: (1,1) stays (1,1) and (3,1) remains (3,1), but (2,1) -> (2,1.5) etc.
        return x, y + ((x + 1) % 2) / 2.
    end

    local function get_angle(from_hex, to_hex)
        -- Returns the angle of the direction from @from_hex to @to_hex
        -- Angle is in radians and goes from -pi to pi. 0 is toward east.
        -- Input hex tables can be of form { x, y } or { x = x, y = y }, which
        -- means that it is also possible to pass a unit table
        local x1, y1 = from_hex.x or from_hex[1], from_hex.y or from_hex[2]
        local x2, y2 = to_hex.x or to_hex[1], to_hex.y or to_hex[2]

        local _, y1cart =  cartesian_coords(x1, y1)
        local _, y2cart =  cartesian_coords(x2, y2)

        return math.atan2(y2cart - y1cart, x2 - x1)
    end

    local function get_direction_index(from_hex, to_hex, n, center_on_east)
        -- Returns an integer index for the direction from @from_hex to @to_hex
        -- with the full circle divided into @n slices
        -- 1 is always to the east, with indices increasing clockwise
        -- Input hex tables can be of form { x, y } or { x = x, y = y }, which
        -- means that it is also possible to pass a unit table
        --
        -- Optional input:
        -- @center_on_east (false): boolean. By default, the eastern direction is the
        -- northern border of the first slice. If this parameter is set, east will
        -- instead be the center direction of the first slice

        local d_east = 0
        if center_on_east then d_east = 0.5 end

        local angle = get_angle(from_hex, to_hex)
        local index = math.floor((angle / math.pi * n/2 + d_east) % n ) + 1

        return index
    end

    function get_hex_facing(from_hex, to_hex)
        local dirs = { 'se', 'sw', 'nw', 'ne' }

        local index = get_direction_index(from_hex, to_hex, 4)
        local index2 = (index + 2) % 4
        if (index2 == 0) then index2 = 4 end

        if (from_hex.y == to_hex.y) and (((from_hex.x - to_hex.x) % 2) == 0) then
            if (from_hex.x > to_hex.x) then
                return 'sw', 'se'
            else
                return 'se', 'sw'
            end
        else
            return dirs[index], dirs[index2]
        end
    end

    -- In principle, 'facing' can be modified directly. However, that only
    -- updates the unit parameters, not the display on the map.
    -- Thus, we create a local copy, change that and then place it back on the map.
    local unit = wesnoth.get_units { id = cfg.id }[1]
    if (not unit) then
        wesnoth.message('[adjust_facing]: unit does not exist: id=' .. cfg.id)
        return
    end
    local unit = wesnoth.copy_unit(unit)

    local second_unit = wesnoth.get_units { id = cfg.second_id }[1]
    if (not second_unit) then
        wesnoth.message('[adjust_facing]: unit does not exist: second_id=' .. cfg.second_id)
        return
    end
    local second_unit = wesnoth.copy_unit(second_unit)

    local facing, second_facing = get_hex_facing({ x = unit.x, y = unit.y }, { x = second_unit.x, y = second_unit.y })

    unit.facing = facing
    if wesnoth.compare_versions(wesnoth.game_config.version, '>=', '1.13.2') then
        wesnoth.put_unit(unit, unit.x, unit.y)
    else
        wesnoth.put_unit(unit.x, unit.y, unit)
    end

    -- Both false and the empty string count as negatives here
    if ((not cfg.speaker_only) or (cfg.speaker_only == '')) then
        second_unit.facing = second_facing
        if wesnoth.compare_versions(wesnoth.game_config.version, '>=', '1.13.2') then
            wesnoth.put_unit(second_unit, second_unit.x, second_unit.y)
        else
            wesnoth.put_unit(second_unit.x, second_unit.y, second_unit)
        end
    end
end

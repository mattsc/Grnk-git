local H = wesnoth.require "lua/helper.lua"
local W = H.set_wml_action_metatable {}
local AH = wesnoth.require "ai/lua/ai_helper.lua"
local LS = wesnoth.require "lua/location_set.lua"

wesnoth.require "~/add-ons/Grnk/lua/set_CA_args.lua"

local hold_area = {}
local stored_y0

local ca_lizards = {}

function ca_lizards:evaluation(arg1)
    local ai = set_CA_args(arg1)

    -- Have the AI form a line along y = 28 - 0.5 * x
    -- if there are no enemies on or south of the line y = 24 - 0.5 * x
    -- Otherwise we'll let the RCA AI do combat as usual,
    -- but this CA takes over all movement other than combat

    --print('---- Evaluating hold_area ----')

    local units
    if wesnoth.get_variable('S') and wesnoth.get_variable('S.include_leader_S' .. wesnoth.current.side) then
        units = AH.get_live_units { side = wesnoth.current.side,
            formula = '$this_unit.moves > 0'
        }
    else
        units = AH.get_live_units { side = wesnoth.current.side, canrecruit = 'no',
            formula = '$this_unit.moves > 0'
        }
    end
    if (not units[1]) then return 0 end

    -- Only Side 3 units are considered here (that is, no lurkers and mosquitos)
    local enemies = AH.get_live_units { side = 3 }

    -- First, determine how far south to form the line
    -- Default is with y0 = 28, but farther south if enemies have broken through
    local y0 = 28
    for i,e in ipairs(enemies) do
        -- Is this enemy south of the line?
        local y_dist = e.y - math.ceil(y0 - 0.5 * e.x)
        --print(e.id, y_dist, y0)
        if (y_dist >= 0) then y0 = y0 + y_dist + 1 end
        --print(y0)
    end
    -- But don't go arbitrarily far south
    if (wesnoth.current.side == 1) and (y0 > 41) then y0 = 41 end
    if (wesnoth.current.side == 2) and (y0 > 36) then y0 = 36 end
    --print('Forming line with y0 = ', y0)

    -- Now find all the enemies that are no more than 4 hexes north of the line
    local close_enemies = {}
    for i,e in ipairs(enemies) do
        local y_line = math.ceil((y0 - 4) - 0.5 * e.x)
        if (e.y >= y_line) then
            table.insert(close_enemies, e)
        end
    end
    --print('Found the following enemies close enough to attack', #close_enemies)
    --for i,e in ipairs(close_enemies) do print('  ', e.id, e.name) end

    -- So now we set the attacks aspect to only those IDs (plus any lurker)
    -- This is slightly evil, but only slightly :-)
    local ids = 'xxx'  -- We cannot pass the empty ID string, that counts as 'all units'
    for i,e in ipairs(close_enemies) do ids = ids .. ',' .. e.id end
    --print('ID string: ', ids)

    -- Always delete the attacks aspect first, so that we do not end up with 100 copies of the facet
    --print("Deleting attacks aspect")
    W.modify_ai {
        side = wesnoth.current.side,
        action = "try_delete",
        path = "aspect[attacks].facet[limited_attack]"
    }

    --print("Setting attacks aspect")
    -- Only attack units given in 'ids', plus any lurker
    W.modify_ai {
        side = wesnoth.current.side,
        action = "add",
        path = "aspect[attacks].facet",
        { "facet", {
           name = "testing_ai_default::aspect_attacks",
           id = "limited_attack",
           invalidate_on_gamestate_change = "yes",
           { "filter_enemy", { id = ids, { "or", { type = "Swamp Lurker" } } } }
        } }
    }

    -- At this point, attacks will happen only on units deemed close enough,
    -- so we can always return a score lower than the combat CA score
    -- We do want to set y0 though, so that the derivation doesn't have to be repeated
    stored_y0 = y0
    return 90000
end

function ca_lizards:execution(arg1)
    local ai = set_CA_args(arg1)

    --print('---- Executing hold_area ----')

    local units
    if wesnoth.get_variable('S') and wesnoth.get_variable('S.include_leader_S' .. wesnoth.current.side) then
        units = AH.get_live_units { side = wesnoth.current.side,
            formula = '$this_unit.moves > 0'
        }
    else
        units = AH.get_live_units { side = wesnoth.current.side, canrecruit = 'no',
            formula = '$this_unit.moves > 0'
        }
    end

    local y0 = stored_y0
    --print('Forming line with y0 = ', y0)

    -- Now figure out which unit to move first
    local max_rating, best_unit, best_hex = -9e99, {}, {}
    for i,u in ipairs(units) do

        -- Extract all the other units first, for path finding
        for j,u2 in ipairs(units) do
            if (u2.x ~= u.x) or (u2.y ~= u.y) then
                wesnoth.extract_unit(u2)
            end
        end

        local reach_map = AH.get_reachable_unocc(u)

        -- Put the other units back out there
        for j,u2 in ipairs(units) do
            if (u2.x ~= u.x) or (u2.y ~= u.y) then
                wesnoth.put_unit(u2.x, u2.y, u2)
            end
        end

        local rating_map = LS.create()
        reach_map:iter( function(x, y, v)
            -- Some of the following information is hardcoded for the map
            -- Needs to be changed (or generalized) if used elsewhere

            -- The AI's keep location
            local x1, y1 = 24, 30  -- Side 1 keep
            if (wesnoth.current.side == 2) then x1, y1 = 12, 31 end  -- Side 2 keep

            local x2, y2 = 14, 3  -- Side 3 keep (Vanak/Grnk)

            -- y_dist is the distance from the line y = y0 - 0.5 * x
            local y_dist = y - math.ceil(y0 - 0.5 * x)
            local rating = - math.abs(y_dist) * 10
            -- Somewhat discourage hexes north of the line
            if (y_dist < 0) then rating = rating - 20 end

            -- Also want this to be on the line between own keep and enemy keep
            local x_on_line = x1 + (x2 - x1) / (y2 - y1) * ( y - y1 )
            rating = rating + math.floor( - math.abs(x - x_on_line) )

            -- 10 defense rating % have slightly higher effect than going one hex left or right
            local defense = 100 - wesnoth.unit_defense(u, wesnoth.get_terrain(x, y))
            rating = rating + defense / 9.

            -- If the unit is very injured, strongly prefer villages (south of the line)
            if (u.hitpoints < u.max_hitpoints/2) then
                local is_village = wesnoth.get_terrain_info(wesnoth.get_terrain(x, y)).village
                if is_village and (y_dist >= 0) then
                    rating = rating + 10000
                    -- And move weakest unit first
                    rating = rating - u.hitpoints * 10
                end
            end

            -- Tie breaker: move strongest unit first
            rating = rating + u.hitpoints / 100.

            rating_map:insert(x, y, rating)

            if (rating > max_rating) then
                max_rating, best_unit, best_hex = rating, u, {x, y}
            end
        end)

        --AH.put_labels(rating_map)
        --W.message { speaker = u.id, message = 'My rating map' }
    end

    AH.movefull_outofway_stopunit(ai, best_unit, best_hex[1], best_hex[2], { dx = 0, dy = 1 })
end

return ca_lizards

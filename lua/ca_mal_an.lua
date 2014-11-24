local H = wesnoth.require "lua/helper.lua"
local W = H.set_wml_action_metatable {}
local AH = wesnoth.require "ai/lua/ai_helper.lua"
local LS = wesnoth.require "lua/location_set.lua"

local ca_mal_an = {}

function ca_mal_an:evaluation(ai)
    -- Have the AI form a line along y = 0.5 * x
    -- Otherwise we'll let the RCA AI do combat as usual,
    -- but this CA takes over all movement other than combat

    -- Only do this when Mal An is on the map, so that skeletons behave normally in Parts b and c
    local mal_an = wesnoth.get_units { id = 'Mal An' }[1]
    if (not mal_an) then return 0 end

    local units = wesnoth.get_units { side = wesnoth.current.side, canrecruit = 'no',
        formula = '$this_unit.moves > 0'
    }
    if (not units[1]) then return 0 end

    -- Don't form the line if there are player units within 3 hexes south and west of
    -- Mal An's keep, or within 6 hexes north and east
    local Mal_x = wesnoth.get_variable("S.keep_Mal_An.x")
    local Mal_y = wesnoth.get_variable("S.keep_Mal_An.y")

    local enemies = wesnoth.get_units { side = "2,3,5" }
    for i,enemy in ipairs(enemies) do
        if (enemy.x - Mal_x >= -3) and (enemy.x - Mal_x <= 6) and
            (enemy.y - Mal_y >= -6) and (enemy.y - Mal_y <= 3)
        then
            print(enemy.id, 'too close')
            return 0
        end
    end

    return 90000
end

function ca_mal_an:execution(ai)
    --print('---- Executing hold_area ----')

    local units = wesnoth.get_units { side = wesnoth.current.side, canrecruit = 'no',
        formula = '$this_unit.moves > 0'
    }

    -- Account for changes in map during the scenario:
    local y_off = wesnoth.get_variable("S.keep_Mal_An.y") - 6

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

            -- y_dist is the distance from the line y = 0.5 * x for the
            -- first part of the scenario (with an offset in Part d).
            local y_dist = y - math.ceil(0.5 * x) - y_off
            local rating = - math.abs(y_dist) * 10
            -- Do not move to hexes south of the line
            if (y_dist > 0) then rating = rating - 2000 end

            -- Do not extend the line past x=13 to the west
            if (x < 13) then rating = rating - 2000 end

            -- Concentrate around x=18
            rating = rating - math.abs(x - 18)

            -- 10 defense rating % have slightly higher effect than going one hex left or right
            local defense = 100 - wesnoth.unit_defense(u, wesnoth.get_terrain(x, y))
            rating = rating + defense / 9.

            -- If the unit is severely injured, strongly prefer villages (north of the line)
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

    AH.movefull_outofway_stopunit(ai, best_unit, best_hex[1], best_hex[2], { dx = 0, dy = -1 })
end

return ca_mal_an

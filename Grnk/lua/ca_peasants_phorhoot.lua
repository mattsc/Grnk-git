local H = wesnoth.require "lua/helper.lua"
local LS = wesnoth.require "lua/location_set.lua"

wesnoth.require "~/add-ons/Grnk/lua/set_CA_args.lua"

local ca_peasants_phorhoot = {}

function ca_peasants_phorhoot:evaluation(arg1)
    local ai = set_CA_args(arg1)

    -- This CA exclusively controls all peasants and boats
    local units = wesnoth.get_units {
        side = 2,
        type = 'Peasant,Boat',
        formula = '$this_unit.moves > 0'
    }

    if units[1] then return 300000 end
    return 0
end

function ca_peasants_phorhoot:execution(arg1)
    local ai = set_CA_args(arg1)

    -- First, all boats that don't have the 'loaded' variable set
    -- have their MP removed
    local boats = wesnoth.get_units {
        side = 2,
        type = 'Boat',
        formula = '$this_unit.moves > 0'
    }

    for _,boat in ipairs(boats) do
        local vars = H.get_child(boat.__cfg, "variables")
        if (not vars.loaded) then
            ai.stopunit_moves(boat)
        end
    end

    -- The we move all other boats and peasants
    local units = wesnoth.get_units {
        side = 2,
        type = 'Peasant,Boat',
        formula = '$this_unit.moves > 0'
    }

    -- Start by testing whether any of the units can get to a
    -- previously unvisited village; the variable itself is controlled in WML
    local unvisited_villages = H.get_variable_array("S.unvisited_villages")
    --print('#unvisited_villages', #unvisited_villages)

    -- Find all unoccupied hexes adjacent to these villages
    local adj_village_map = LS.create()
    for _,village in ipairs(unvisited_villages) do
        local x, y = village.x, village.y

        for xa,ya in H.adjacent_tiles(x, y) do
            local unit = wesnoth.get_unit(xa, ya)
            if (not unit) then
                adj_village_map:insert(xa, ya, { x = x, y = y })
            end
        end
    end
    --print('adj_village_map:size()', adj_village_map:size())

    local max_rating, best_unit, best_hex = -9e99
    for i,unit in ipairs(units) do
        local reach = wesnoth.find_reach(unit)

        for _,hex in ipairs(reach) do
            local adj_village = adj_village_map:get(hex[1], hex[2])
            if adj_village then
                -- Take farthest away unit first
                local rating = H.distance_between(unit.x, unit.y, 26, 36)

                -- And the farthest away village
                rating = rating + H.distance_between(adj_village.x, adj_village.y, 26, 36)

                -- Discourage hexes with low defense
                local defense = 100 - wesnoth.unit_defense(unit, wesnoth.get_terrain(hex[1], hex[2]))
                if (defense < 40) then rating = rating - 0.5 end

                -- And take adjacent hexes closest to fort first
                rating = rating - H.distance_between(hex[1], hex[2], 26, 36) / 100.

                -- Prefer to use boats over peasants, if possible
                if (unit.type == 'Boat') then
                    rating = rating + 1000
                end

                if (rating > max_rating) then
                    max_rating = rating
                    best_unit, best_hex = unit, hex
                end
            end
        end
    end

    if best_unit then
        ai.move(best_unit, best_hex[1], best_hex[2])
        return
    end

    -----------------------------------------------------------
    -- If we got here, units cannot get to any more unvisited villages
    -- -> move toward occupied fort hexes
    local land_adj_occ_fort = wesnoth.get_locations {
        terrain = 'G*,H*,R*',
        { "not", { { "filter" } } },
        { "filter_adjacent_location", {
            terrain = 'C*,K*',
            { "filter", { side = 2 } }
        } }
    }
    --print('#land_adj_occ_fort', #land_adj_occ_fort)

    local water_adj_occ_fort = wesnoth.get_locations {
        terrain = 'Wo',
        { "not", { { "filter" } } },
        { "filter_adjacent_location", {
            terrain = 'C*,K*',
            { "filter", { side = 2 } }
        } }
    }
    --print('#water_adj_occ_fort', #water_adj_occ_fort)

    -- Only keep units that are not more than 6 hexes farther from the main
    -- castle than the closest unit; this is done to speed things up
    -- as path finding is expensive
    local min_dist, distances = 9e99, {}
    for i,unit in ipairs(units) do
        local dist = H.distance_between(unit.x, unit.y, 26, 36)
        distances[i] = dist
        if (dist < min_dist) then min_dist = dist end
    end

    for i=#units,1,-1 do
        if (distances[i] > min_dist + 6) then
            table.remove(units, i)
        end
    end

    -- Find the best goal hex for each unit to go to
    local max_rating, best_unit, best_goal = -9e99
    for _,unit in ipairs(units) do
        local goals
        if (unit.type == 'Peasant') then
            goals = land_adj_occ_fort
        else
            goals = water_adj_occ_fort
        end

        -- Sort goals by distance from the unit
        for _,goal in ipairs(goals) do
            goal.distance = H.distance_between(goal[1], goal[2], unit.x, unit.y)
        end
        table.sort(goals, function(a, b) return a.distance < b.distance end)

        local max_rating_unit, best_goal_unit = -9e99
        for _,goal in ipairs(goals) do
            -- Don't continue if next goal is farther away than best cost found
            -- so far (to speed things up)
            if (goal.distance > - max_rating_unit * unit.max_moves) then break end

            local _, cost = wesnoth.find_path(unit, goal[1], goal[2])

            -- This is kind of a weird rating ...
            local rating_unit = - cost / unit.max_moves

            if (rating_unit > max_rating_unit) then
                max_rating_unit, best_goal_unit = rating_unit, goal
            end
        end

        -- Original rating is simply the cost (in turns) to get there
        -- However, for units that can get there on the same move, we
        -- actually want the ones farther away to go first. The
        -- motivation is that closer units can likely get to other goals too.
        if best_goal_unit then
            local rating = math.ceil(max_rating_unit)
            rating = rating + (math.ceil(max_rating_unit) - max_rating_unit)

            if (rating > max_rating) then
                max_rating = rating
                best_unit, best_goal = unit, best_goal_unit
            end
        end
    end

    -- We can't just do a next_hop here though, as that often causes units
    -- to line up in one long line
    if best_goal then
        local reach = wesnoth.find_reach(best_unit)

        local unit_copy = wesnoth.copy_unit(best_unit)

        local max_rating, best_hex = -10000  -- To exclude impassable terrain
        for _,hex in ipairs(reach) do
            local unit_in_way = wesnoth.get_unit(hex[1], hex[2])
            if (not unit_in_way) then
                unit_copy.x, unit_copy.y = hex[1], hex[2]
                local _, cost = wesnoth.find_path(unit_copy, best_goal[1], best_goal[2])

                local rating = -cost

                if (rating > max_rating) then
                    max_rating, best_hex = rating, hex
                end
            end
        end

        if best_hex then
            ai.move_full(best_unit, best_hex[1], best_hex[2])
            return
        end
    end

    -----------------------------------------------------------
    -- If we got here, nothing can be done, so we simply stop all units
    for _,unit in ipairs(units) do
        ai.stopunit_moves(unit)
    end
end

return ca_peasants_phorhoot

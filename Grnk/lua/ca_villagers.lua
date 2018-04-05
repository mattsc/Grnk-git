local H = wesnoth.require "lua/helper.lua"
local AH = wesnoth.require "ai/lua/ai_helper.lua"
local MAIUV = wesnoth.require "ai/micro_ais/micro_ai_unit_variables.lua"

wesnoth.require "~/add-ons/Grnk/lua/set_CA_args.lua"

local function get_villager()
    local villagers = AH.get_units_with_moves { side = wesnoth.current.side }
    return villagers[1]
end

local ca_villagers = {}

function ca_villagers:evaluation(arg1)
    local ai = set_CA_args(arg1)

    if get_villager() then return 90000 end
    return 0
end

function ca_villagers:execution(arg1)
    local ai = set_CA_args(arg1)

    -- This is a modified (much simplified) version of the Big Animals MAI.
    -- It only takes care of the wandering, does not need to avoid anybody
    -- and leaves attacks to the mainline AI.

    local villager = get_villager()

    local goal = MAIUV.get_mai_unit_variables(villager, 'villagers')

    -- Unit gets a new goal if none is set or on any move with a 10% random chance
    local r = math.random(10)
    if (not goal.goal_x) or (r == 1) then
        local locs = AH.get_passable_locations { find_in = 'S2.villages' }
        local rand = math.random(#locs)

        goal.goal_x, goal.goal_y = locs[rand][1], locs[rand][2]
        MAIUV.set_mai_unit_variables(villager, 'villagers', goal)
        --print('Setting goal:', villager.id, goal.goal_x, goal.goal_y, 'random:', r)
    end

    local reach_map = AH.get_reachable_unocc(villager)

    -- Now find the one of these hexes that is closest to the goal
    local max_rating, best_hex = -9e99
    reach_map:iter( function(x, y, v)
        local rating = - H.distance_between(x, y, goal.goal_x, goal.goal_y)

        if (rating > max_rating) then
            max_rating, best_hex = rating, { x, y }
        end
    end)

    if (best_hex[1] ~= villager.x) or (best_hex[2] ~= villager.y) then
        AH.checked_move_full(ai, villager, best_hex[1], best_hex[2])
        if (not villager) or (not villager.valid) then return end
    else  -- If unit did not move, we need to stop it (also delete the goal)
        AH.checked_stopunit_moves(ai, villager)
        if (not villager) or (not villager.valid) then return end
        MAIUV.delete_mai_unit_variables(villager, 'villagers')
    end

    if (villager.x == goal.goal_x) and (villager.y == goal.goal_y) then
        --print('Removing villager at goal', villager.id, villager.x, villager.y, goal.goal_x, goal.goal_y)
        if wesnoth.compare_versions(wesnoth.game_config.version, '>=', '1.13.12') then
            wesnoth.invoke_synced_command("villager_disappears_at_goal", goal)
        else
            local command = "wesnoth.put_unit(x1, y1)"
            ai.synced_command(command, goal.goal_x, goal.goal_y)
        end
    end
end

return ca_villagers

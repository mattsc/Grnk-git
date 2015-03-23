local H = wesnoth.require "lua/helper.lua"
local AH = wesnoth.require "ai/lua/ai_helper.lua"

local function get_dog(cfg)
    local dogs = AH.get_units_with_moves {
        side = wesnoth.current.side,
        { "and", cfg.filter },
    }
    return dogs[1]
end

-- This CA simply takes moves away from all dogs. This is done in order
-- to work around a bug in the herding Micro AI, where dogs adjacent to sheep
-- may be left with moves left.

local ca_dogs_move_no_more = {}

function ca_dogs_move_no_more:evaluation(ai, cfg)
    if get_dog(cfg) then return 299990 end
    return 0
end

function ca_dogs_move_no_more:execution(ai, cfg)
    local dog = get_dog(cfg)

    AH.checked_stopunit_moves(ai, dog)
end

return ca_dogs_move_no_more

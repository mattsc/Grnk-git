local AH = wesnoth.require "ai/lua/ai_helper.lua"

local adv = {}

function adv.advances_from(to_type, level, n)
    -- Finds which unit type a unit advances from
    -- INPUTS:
    --  - to_type: (string) the unit type for which advance_to values are to be found
    --  - level: (int) the level of the previous unit type that is sought; defaults to one
    --      level below the unit specified by to_type.
    --      If set to -1, returns lowest level type of unit line
    --
    -- Note: do not touch the 'n' parameter; it's an internal parameter
    --
    -- Returns nil if no unit type is found

    n = n or 0  -- Just a saveguard against infinite recursion; shouldn't really be needed, at least not in mainline
    local from_type, from_level

    for i,unit_type in pairs(wesnoth.unit_types) do
        if (unit_type.level == (wesnoth.unit_types[to_type].level - 1)) then
            local adv_to = AH.split(unit_type.__cfg.advances_to or "") -- table containing all advance_to types
            for j,ut in ipairs(adv_to) do
                if (ut == to_type) then
                    from_type, from_level = unit_type.id, unit_type.level
                    break
                end
            end
        end
        if from_type then break end
    end

    if from_type and level and (from_level > level) and (n < 100) then
        local tmp_type = adv.advances_from(from_type, level, n + 1)
        if tmp_type or (level ~= -1) then
            from_type = tmp_type
        end
    end

    return from_type
end

return adv

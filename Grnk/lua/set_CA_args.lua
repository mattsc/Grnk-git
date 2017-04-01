function set_CA_args(arg1, arg2)
    local ai, cfg = ai, arg1
    if wesnoth.compare_versions(wesnoth.game_config.version, '<', '1.13.5') then
        ai, cfg = arg1, arg2
    end
    return ai, cfg
end

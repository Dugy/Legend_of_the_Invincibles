-- EFFECT TO CHANGE LEVEL
-- Use on [effect]
-- apply_to=level
-- increase=number or $formula
-- set=number or $formula

function wesnoth.effects.level(unit, cfg)
    if cfg.set then
        unit.level = cfg.set
    elseif cfg.increase then
        unit.level = unit.level + cfg.increase
    else
        wml.error("Invalid or missing key in [effect] apply_to=level")
    end
end

local H = wesnoth.require "lua/helper.lua"
local W = H.set_wml_action_metatable {}
local MAIH = wesnoth.require("ai/micro_ais/micro_ai_helper.lua")

function wesnoth.wml_actions.micro_ai_fast(cfg)
    local CA_path = '~add-ons/Legend_of_the_Invincibles/ai/'

    cfg = cfg.__parsed

    -- Check that the required common keys are all present and set correctly
    if (not cfg.ai_type) then H.wml_error("[micro_ai] is missing required ai_type= key") end
    if (not cfg.side) then H.wml_error("[micro_ai] is missing required side= key") end
    if (not cfg.action) then H.wml_error("[micro_ai] is missing required action= key") end
    if (not wesnoth.sides[cfg.side]) then
        wesnoth.message("Warning", "[micro_ai] uses side=" .. cfg.side .. ": side does not exist")
        return
    end
    if (cfg.action ~= 'add') and (cfg.action ~= 'delete') and (cfg.action ~= 'change') then
        H.wml_error("[micro_ai] unknown value for action=. Allowed values: add, delete or change")
    end

    -- Set up the configuration tables for the different Micro AIs
    local required_keys, optional_keys, CA_parms = {}, {}, {}

    --------- Fast Micro AI ------------------------------------
    if (cfg.ai_type == 'fast_ai') then
        required_keys = {}
        optional_keys = {
             "attack_hidden_enemies", "avoid", "dungeon_mode",
             "filter", "filter_second", "include_occupied_attack_hexes",
             "leader_additional_threat", "leader_attack_max_units", "leader_weight", "move_cost_factor",
             "weak_units_first", "skip_combat_ca", "skip_move_ca", "threatened_leader_fights"
        }
        CA_parms = {
            ai_id = 'mai_fast',
            { ca_id = 'combat', location = CA_path .. 'ca_fast_combat.lua', score = 100000 },
            { ca_id = 'move', location = CA_path .. 'ca_fast_move.lua', score = 20000 },
            { ca_id = 'combat_leader', location = CA_path .. 'ca_fast_combat_leader.lua', score = 19900 }
        }

        -- Also need to delete/add the default recruitment CA
        if (cfg.action == 'delete') then
            -- This can be done independently of whether these were removed earlier
            W.modify_ai {
                side = cfg.side,
                action = "add",
                path = "stage[main_loop].candidate_action",
                { "candidate_action", {
                    id="combat",
                    engine="cpp",
                    name="ai_default_rca::combat_phase",
                    max_score=100000,
                    score=100000
                } }
            }

            W.modify_ai {
                side = cfg.side,
                action = "add",
                path = "stage[main_loop].candidate_action",
                { "candidate_action", {
                    id="villages",
                    engine="cpp",
                    name="ai_default_rca::get_villages_phase",
                    max_score=60000,
                    score=60000
                } }
            }

            W.modify_ai {
                side = cfg.side,
                action = "add",
                path = "stage[main_loop].candidate_action",
                { "candidate_action", {
                    id="retreat",
                    engine="cpp",
                    name="ai_default_rca::retreat_phase",
                    max_score=40000,
                    score=40000
                } }
            }

            W.modify_ai {
                side = cfg.side,
                action = "add",
                path = "stage[main_loop].candidate_action",
                { "candidate_action", {
                    id="move_to_targets",
                    engine="cpp",
                    name="ai_default_rca::move_to_targets_phase",
                    max_score=20000,
                    score=20000
                } }
            }
        else
            if (not cfg.skip_combat_ca) then
                W.modify_ai {
                    side = cfg.side,
                    action = "try_delete",
                    path = "stage[main_loop].candidate_action[combat]"
                }
            else
                for i,parm in ipairs(CA_parms) do
                    if (parm.ca_id == 'combat') or (parm.ca_id == 'combat_leader') then
                        table.remove(CA_parms, i)
                        break
                    end
                end
            end

            if (not cfg.skip_move_ca) then
                W.modify_ai {
                    side = cfg.side,
                    action = "try_delete",
                    path = "stage[main_loop].candidate_action[villages]"
                }

                W.modify_ai {
                    side = cfg.side,
                    action = "try_delete",
                    path = "stage[main_loop].candidate_action[retreat]"
                }

                W.modify_ai {
                    side = cfg.side,
                    action = "try_delete",
                    path = "stage[main_loop].candidate_action[move_to_targets]"
                }
            else
                for i,parm in ipairs(CA_parms) do
                    if (parm.ca_id == 'move') then
                        table.remove(CA_parms, i)
                        break
                    end
                end
            end
        end

    else
        H.wml_error("unknown value for ai_type= in [micro_ai]")
    end

    MAIH.micro_ai_setup(cfg, CA_parms, required_keys, optional_keys)
end

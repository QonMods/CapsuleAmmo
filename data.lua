local mod_name = 'CapsuleAmmo'
local mul = require('math3d').vector2.mul

local sep = ':'

local ammo_list = {'piercing-rounds-magazine', --[['firearm-magazine',--]] 'rocket','explosive-rocket', 'land-mine', 'artillery-shell'}
if settings.startup['capsule-ammo-enable-extra-laser-ammo-types'].value then 
    table.insert(ammo_list, 'laser-turret')
    table.insert(ammo_list, 'personal-laser-defense-equipment')
    -- table.insert(ammo_list, 'distractor-capsule')
end

local split_to_group_count = 2

local TECH_BASE = settings.startup['capsule-ammo-technology'].value == 'Levels only' or settings.startup['capsule-ammo-technology'].value == 'Complete'
local TECH_INDIVIDUAL = settings.startup['capsule-ammo-technology'].value == 'Individual recipes' or settings.startup['capsule-ammo-technology'].value == 'Complete'
local TECH_INDIVIDUAL_INGREDIENT_PREREQUISITE = settings.startup['capsule-ammo-technology'].value == 'Complete'

function string:split(sep)
   local sep, fields = sep or ":", {}
   local pattern = string.format("([^%s]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

local ammo_filters = settings.startup['capsule-ammo-blacklist-ammo'].value:split(' ')
for i = #ammo_list, 1, -1 do -- filter
    local allow = true
    for ii, vv in ipairs(ammo_filters) do
        if ammo_list[i] == vv then 
            allow = false 
        end
    end
    if not allow then
        table.remove(ammo_list, i)
    end
end

function lit(list) return (#list > 0 and list or {list}) end

function leftpad0(s, n)
    return string.rep('0', math.max(0, n - #(''..s)))..s
    -- s = ''..s
    -- if #s >= n then return s end
    -- return leftpad0('0'..s, n)
end

function delta(i, total, scale)
    if scale == nil then scale = total end
    return mul({math.cos(math.pi * 2 * i / total), math.sin(math.pi * 2 * i / total)}, scale)
end

local new_name = function(ammo, capsule_names)
    local s = '<'..ammo.name
    for _, capsule_name in ipairs(capsule_names) do
        s = s..sep..capsule_name
    end
    return s..'>'
end

local extensions = {}

local find_recipe_tech_memo = {}
function find_recipe_tech(recipe_name)
    if find_recipe_tech_memo[recipe_name] then return find_recipe_tech_memo[recipe_name] end
    for tech_name, technology in pairs(data.raw.technology) do
        for _, effect in ipairs(technology.effects or {}) do
            if effect.type == 'unlock-recipe' and effect.recipe == recipe_name then
                find_recipe_tech_memo[recipe_name] = tech_name
                return tech_name
            end
        end
    end
end

function get_tech_ingredients(n)
    local ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"military-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1}
    }
    for i = #ingredients, n + 1, -1 do
        table.remove(ingredients)
    end
    return ingredients
end

function make_localised_name(ammo, capsules)
    local capsule_list_localised_name = {''}
    for i, capsule in ipairs(capsules) do
        if 1 < i and i < #capsules then table.insert(capsule_list_localised_name, ', ') end
        if 1 < i and i == #capsules then
            table.insert(capsule_list_localised_name, ' ')
            table.insert(capsule_list_localised_name, {'item-name.list-and-separator'})
            table.insert(capsule_list_localised_name, ' ')
        end
        table.insert(capsule_list_localised_name, capsule.localised_name or {(capsule.name == 'land-mine' and 'entity-name.' or 'item-name.')..capsule.name})
    end
    return {'item-name.ammo-with-capsules',  {((ammo.name == 'land-mine' --[[or ammo.name == 'distractor-capsule'--]]) and 'entity-name.' or ammo.name == 'personal-laser-defense-equipment' and 'equipment-name.' or 'item-name.')..ammo.name}, capsule_list_localised_name}
end

function collect_actions(capsules)
    local capsules_with_valid_actions_table = {}
    local valid_count = 0
    local actions = {}
    for i, capsule in ipairs(capsules) do
        local ammo_type = capsule.ammo_type
        if not ammo_type and capsule.capsule_action then
            if capsule.capsule_action.type == 'throw' and
                        capsule.capsule_action.attack_parameters and
                        capsule.capsule_action.attack_parameters.type == 'projectile'
            then
                ammo_type = capsule.capsule_action.attack_parameters.ammo_type
            elseif capsule.capsule_action.type == 'artillery-remote' then
                table.insert(actions, {
                    type = 'direct',
                    ignore_collision_condition = true,
                    action_delivery = {
                        type = 'instant',
                        target_effects = {
                            type = 'create-entity',
                            check_buildability = false,
                            entity_name = capsule.capsule_action.flare
                        }
                    }
                })
                if not capsules_with_valid_actions_table[i] then
                    capsules_with_valid_actions_table[i] = true
                    valid_count = valid_count + 1
                end
            end
        end
        if ammo_type --[[and ammo_type.target_type == 'position'--]] then
            -- local action_list = ammo_type.action
            -- if action_list.type then action_list = {action_list} end -- should be here but incompatible with RampantArsenal atm. Without this incompatible items are skipped instead of failing on start up.
            for _, act in ipairs(lit(ammo_type.action)) do
                if act.action_delivery and act.action_delivery.type == 'projectile' then
                    for _, action_item in ipairs(lit(data.raw.projectile[act.action_delivery.projectile].action)) do
                        table.insert(actions, table.deepcopy(action_item))
                        if not capsules_with_valid_actions_table[i] then
                            capsules_with_valid_actions_table[i] = true
                            valid_count = valid_count + 1
                        end
                    end
                end
            end
        end
        if capsule.action then
            table.insert(actions, capsule.action)
            if not capsules_with_valid_actions_table[i] then
                capsules_with_valid_actions_table[i] = true
                valid_count = valid_count + 1
            end
        end
        if capsule.place_result then
            table.insert(actions, {
                type = 'direct',
                ignore_collision_condition = false,
                action_delivery = {
                    type = 'instant',
                    target_effects = {
                        type = 'create-entity',
                        check_buildability = true,
                        entity_name = capsule.place_result
                    }
                }
            })
            if not capsules_with_valid_actions_table[i] then
                capsules_with_valid_actions_table[i] = true
                valid_count = valid_count + 1
            end
        end
    end
    return actions, valid_count
end

local capsule_list = {}
for _, capsule in pairs(data.raw.capsule) do
    table.insert(capsule_list, capsule)
end
table.sort(capsule_list, function(a, b)
    if data.raw['item-subgroup'][a.subgroup].order < data.raw['item-subgroup'][b.subgroup].order then
        return true
    elseif data.raw['item-subgroup'][a.subgroup].order > data.raw['item-subgroup'][b.subgroup].order then
        return false
    end
    return a.order < b.order
end)
table.insert(capsule_list, data.raw.item['land-mine'])
-- table.insert(capsule_list, data.raw['land-mine']['land-mine'])
-- table.insert(capsule_list, data.raw.ammo['explosive-rocket'])
table.insert(capsule_list, data.raw.ammo['atomic-bomb'])

local capsule_filters = settings.startup['capsule-ammo-blacklist-capsule'].value:split(' ')
for i = #capsule_list, 1, -1 do -- filter
    local actions, valid_count = collect_actions({capsule_list[i]})
    local allow = true
    for ii, filtered_name in ipairs(capsule_filters) do
        if capsule_list[i].name == filtered_name then 
            allow = false 
        end
    end
    if #actions == 0 or not allow then
        table.remove(capsule_list, i)
    end
end
local internal_capsule_order = {}
for i, capsule in ipairs(capsule_list) do
    internal_capsule_order[capsule.name] = i
end
local capsule_order_padlen = math.ceil(math.log(#capsule_list + 1)/math.log(10))
-- log('#capsule_list: '..#capsule_list)
-- log('capsule_order_padlen: '..capsule_order_padlen)

local shorten_order_string = {}
local recipe_with_base_tech_requirement = {}
function make_capsule_ammo(ammo, capsules)
    local capammo = table.deepcopy(ammo)
    -- Predictable order gives us the same item with the same set of ammo and capsules, even if their .order is changed by other mod!
    -- But we don't want to use it everywhere else because we want the order of things visible to the player to be in same order as in gui
    local capsule_names_sorted = {}
    for _, capsule in ipairs(capsules) do table.insert(capsule_names_sorted, ((capsule.name == 'land-mine') and capsule.type..'-' or '')..capsule.name) end
    table.sort(capsule_names_sorted, function(a, b) return a < b end)

    local localised_name = make_localised_name(ammo, capsules)

    local actions, valid_count = collect_actions(capsules)
    if #actions > 0 --[[and valid_count == #capsules--]] then
        actions = table.deepcopy(actions)
        capammo.name = new_name(capammo, capsule_names_sorted)
        if #capammo.name > 200 then
            log(capammo.name..': Failed to create prototype due to name length being '..#capammo.length..'/200 characters')
            return nil
        end
        -- capammo.magazine_size = math.ceil((capammo.magazine_size or 1) / 4)
        -- capammo.reload_time = 15

        function find_action_delivery(ammo, ad_types)
            if ammo.place_result then
                local f = ad_types[ammo.place_result]
                if f then
                    return f(ammo)
                end
            end
            if ammo.placed_as_equipment_result then
                local f = ad_types[ammo.placed_as_equipment_result]
                if f then
                    return f(ammo)
                end
            end
            -- log(ammo.type)
            -- log(ammo.name)
            if ammo.type == 'capsule' then
                local f = ad_types[ammo.type]
                if f then
                    return f(ammo)
                end
            end
            -- local has_ammo_type = ammo
            -- if not ammo.ammo_type and ammo.capsule_action and ammo.capsule_action.attack_parameters and ammo.capsule_action.attack_parameters.ammo_type then
            --     has_ammo_type = ammo.capsule_action.attack_parameters
            -- end
            for _, ammo_type in ipairs(lit(ammo.ammo_type)) do
                for _, action in ipairs(lit(ammo_type.action)) do
                    for _, action_delivery in ipairs(lit(action.action_delivery)) do
                        local f = ad_types[action_delivery.type]
                        if f then
                            return f(ammo, ammo_type, action, action_delivery)
                        end
                    end
                end
            end
        end

        function find_path_to_key(obj, key)
            if obj[key] then
                return {obj[key], obj}
            end
            for k, v in pairs(obj) do
                if type(v) == 'table' then
                    local path = find_path_to_key(v, key)
                    if path then
                        table.insert(path, obj)
                        return path
                    end
                end
            end
        end

        -- function find_proxy_with_action_with_target_effect(ammo)
        --     local proxy = data.raw.entity[ammo.place_result]
        --     -- if ammo.place_result then
        --     --     if
        --     -- end
        --     find_proxy_with_action_with_target_effect(proxy)
        -- end

        function has_projectile(_1, _2, _3, action_delivery)
            local projectile = table.deepcopy(data.raw.projectile[action_delivery.projectile] or data.raw['artillery-projectile'][action_delivery.projectile])
            table.insert(extensions, projectile)
            action_delivery.projectile = capammo.name
            projectile.name = capammo.name
            return projectile
        end
        local thing_with_action = find_action_delivery(capammo, {
            projectile = has_projectile,
            ['artillery'] = has_projectile,
            ['land-mine'] = function(ammo)
                local placeable = table.deepcopy(data.raw['land-mine'][ammo.place_result])
                table.insert(extensions, placeable)
                ammo.place_result = ammo.name
                placeable.name = ammo.name
                placeable.localised_name = localised_name
                return placeable.action.action_delivery.source_effects[1]
            end,
            ['laser-turret'] = function(ammo)
                local placeable = table.deepcopy(data.raw['electric-turret'][ammo.place_result])
                table.insert(extensions, placeable)
                ammo.place_result = ammo.name
                placeable.name = ammo.name
                placeable.localised_name = localised_name
                return placeable.attack_parameters.ammo_type--.action.action_delivery
            end,
            ['personal-laser-defense-equipment'] = function(ammo)
                local equipment = table.deepcopy(data.raw['active-defense-equipment'][ammo.placed_as_equipment_result])
                table.insert(extensions, equipment)
                ammo.placed_as_equipment_result = ammo.name
                equipment.name = ammo.name
                equipment.localised_name = localised_name
                return equipment.attack_parameters.ammo_type
            end,
            ['capsule'] = function(ammo)
                local projectile = table.deepcopy(data.raw.projectile['distractor-capsule'])
                table.insert(extensions, projectile)
                ammo.capsule_action.attack_parameters.ammo_type.action[1].action_delivery.projectile = ammo.name
                projectile.name = ammo.name
                -- projectile.action.action_delivery.target_effects[1].entity_name = ammo.name
                -- return projectile

                local pseudoentity = table.deepcopy(data.raw['combat-robot']['distractor'])
                table.insert(extensions, pseudoentity)
                -- ammo. = ammo.name
                pseudoentity.name = ammo.name
                pseudoentity.localised_name = localised_name
                return pseudoentity.ammo_type
            end,
            instant = function(ammo, ammo_type, _3, action_delivery) return ammo_type end
        })

        if thing_with_action then
            local original_actions = lit(thing_with_action.action)

            local probability = 1

            -- for _, action in ipairs(actions) do
            --     if #original_actions == 1 and original_actions[1].force then
            --         action.force = original_actions[1].force
            --         -- log(serpent.block(action))
            --     end
            -- end

            if (capammo.magazine_size or 1) > 1 then
                probability = settings.startup['capsule-ammo-magazine-fraction'].value
                for _, action in ipairs(actions) do
                    action.probability = (action.probability or 1) * probability
                end
            end

            for _, action_item in ipairs(original_actions) do
                table.insert(actions, 1, table.deepcopy(action_item))
            end
            thing_with_action.action = actions

            local tint_scale_position_list = {capammo}
            local not3count = #capsules == 3 and 4 or #capsules
            for i, capsule in ipairs(capsules) do
                local capsule_scaled = table.deepcopy(capsule)
                -- Rounding up to nearest power of 2, to keep icons sharp
                -- math.min(0.5, 2^math.ceil(math.log(1 / #capsules)/math.log(2)))
                capsule_scaled.scale = (capsule_scaled.scale or 1) * #capsules <= 2 and 0.5 or 0.25
                capsule_scaled.shift = delta(not3count / 2 + (i - 1), not3count, (#capsules == 1 and 0) or 0.25)
                capsule_scaled.tint = capsule.icons and capsule.icons[1].tint
                table.insert(tint_scale_position_list, capsule_scaled)
            end
            local icons = {}
            for i, properties in ipairs(tint_scale_position_list) do
                local size = properties.icon_size or (properties.icons and properties.icons[1] and properties.icons[1].icon_size) or nil
                local scale = properties.scale or 1
                table.insert(icons, {
                    icon = properties.icon or (properties.icons and properties.icons[1] and properties.icons[1].icon) or nil,
                    icon_size = size,
                    tint = properties.tint or {r = 1, g = 1, b = 1, a = 1},
                    scale = scale,
                    shift = mul(properties.position or properties.shift or {0, 0}, properties.shift_scale or 64),
                    dark_background_icon = properties.dark_background_icon or (properties.icons and properties.icons[1] and properties.icons[1].dark_background_icon) or nil,
                })
            end
            capammo.icons = icons
            capammo.icon = nil
            capammo.icon_size = nil
            capammo.dark_background_icon = nil

            capammo.order = capammo.order..'-'..leftpad0(#capsules, capsule_order_padlen)..'-'
            for _, capsule in ipairs(capsules) do
                capammo.order = capammo.order..':'..leftpad0(internal_capsule_order[capsule.name], capsule_order_padlen)
            end
            -- if #capammo.order > 200 then
            --     log(capammo.name..'('..#capammo.name..'/200): Failed to create prototype due to order ('..capammo.order..') length being '..#capammo.order..'/200 characters')
            --     return nil
            -- end

            if #capsules >= 2 then capammo.subgroup = ammo.name..'-'..leftpad0(#capsules, capsule_order_padlen) end

            capammo.localised_name = localised_name
            table.insert(extensions, capammo)

            local ingredients_map = {}
            if settings.startup['capsule-ammo-recipe-type'].value ~= 'Simple' and #capsules >= 2 then
                for i, _ in ipairs(capsule_names_sorted) do
                    local subset = table.deepcopy(capsule_names_sorted)
                    table.remove(subset, i)
                    local iname = new_name(ammo, subset)
                    ingredients_map[iname] = ingredients_map[iname] and {iname, ingredients_map[iname][2] + 1} or {iname, 1}
                end
            else
                local iname = ammo.name
                ingredients_map[iname] = ingredients_map[iname] and {iname, ingredients_map[iname][2] + 1} or {iname, 1}
                for _, capsule in ipairs(capsules) do
                    local iname = capsule.name
                    ingredients_map[iname] = ingredients_map[iname] and {iname, ingredients_map[iname][2] + 1} or {iname, 1}
                end
            end
            local ingredients = {}
            for _, v in pairs(ingredients_map) do table.insert(ingredients, v) end
            local recipe = {
                type = "recipe",
                name = capammo.name,
                enabled = not (TECH_BASE or TECH_INDIVIDUAL),
                ingredients = ingredients,
                result = capammo.name,
                result_count = settings.startup['capsule-ammo-recipe-type'].value == 'Complex, cheap' and #capsules or 1,
                order = capammo.order,
                subgroup = capammo.subgroup,
                localised_name = localised_name
            }
            if split_to_group_count <= #capsules then
                table.insert(shorten_order_string, capammo)
                table.insert(shorten_order_string, recipe)
            end
            table.insert(extensions, recipe)

            if TECH_BASE or TECH_INDIVIDUAL then
                local prereq_table = {}
                if TECH_BASE then
                    prereq_table['capsule-ammo-'..#capsules] = true
                    recipe_with_base_tech_requirement[#capsules] = recipe_with_base_tech_requirement[#capsules] or {}
                    table.insert(recipe_with_base_tech_requirement[#capsules], recipe.name)
                end
                if TECH_INDIVIDUAL then
                    if TECH_INDIVIDUAL_INGREDIENT_PREREQUISITE then
                        if #capsules == 1 then
                            for _, ingredient in ipairs(ingredients) do
                                local tech_name = find_recipe_tech(ingredient[1])
                                if tech_name then prereq_table[tech_name] = true end
                            end
                        end
                    end
                    if #capsules >= 2 then
                        for i, _ in ipairs(capsule_names_sorted) do
                            local subset = table.deepcopy(capsule_names_sorted)
                            table.remove(subset, i)
                            prereq_table[new_name(ammo, subset)] = true
                        end
                    end
                    local prerequisites = {}
                    for k, _ in pairs(prereq_table) do table.insert(prerequisites, k) end
                    local technology = {
                        type = 'technology',
                        name = capammo.name,
                        localised_name = capammo.localised_name,
                        icons = capammo.icons,
                        prerequisites = prerequisites,
                        effects = {{type = 'unlock-recipe', recipe = recipe.name}},
                        unit = {
                            count = 100 * #capsules,
                            ingredients = get_tech_ingredients(#capsules * 2),
                            time = math.min(60, 15 * #capsules)
                        },
                        order = capammo.order,
                        upgrade = true
                    }
                    table.insert(extensions, technology)
                end
            end

            return capammo
        end
    end
end

local group = table.deepcopy(data.raw['item-group']['combat'])
group.name = 'capsule-ammo'
group.order = group.order..'-'..2
table.insert(extensions, group)

local subgroups = {}
function make_subgroup(ammo, subgroup, group)
    if subgroup and not data.raw['item-subgroup'][subgroup] and not subgroups[ammo_name] then
        subgroups[subgroup] = table.deepcopy(data.raw['item-subgroup'].ammo)
        subgroups[subgroup].name = subgroup
        subgroups[subgroup].group = group.name
        subgroups[subgroup].order = subgroups[subgroup].order..'-'..ammo.order
        table.insert(extensions, subgroups[subgroup])
    end
end

function for_capsules(ammo, capsules, index, depth)
    if depth == 0 then return #capsules end

    local max_depth = #capsules

    for i = index + 1, #capsule_list do
        local capsule = capsule_list[i]

        table.insert(capsules, capsule)
        local capammo = make_capsule_ammo(ammo, capsules)
        if #capsules >= split_to_group_count then make_subgroup(ammo, capammo and capammo.subgroup, group) end
        if capammo then
            max_depth = math.max(max_depth, for_capsules(ammo, capsules, i, depth - 1))
        end
        table.remove(capsules)
    end
    return max_depth
end

function depth_techs(max_n_capsules)
    log(max_n_capsules)
    for i = 1, max_n_capsules do
        local prerequisites = {}
        if i <= 3 then
            table.insert(prerequisites, 'military-'..(i + 1))
        end
        if i >= 2 then
            table.insert(prerequisites, 'capsule-ammo-'..(i - 1))
        end
        local effects = {}
        if not TECH_INDIVIDUAL then
            for _, recipe_name in ipairs(recipe_with_base_tech_requirement[i]) do
                table.insert(effects, {type = 'unlock-recipe', recipe = recipe_name})
            end
        end
        local military = data.raw.technology['military']
        local depth_tech = {
            type = 'technology',
            name = 'capsule-ammo-'..i,
            icon_size = military.icon_size,
            icon = military.icon, --"__base__/graphics/technology/military.png",
            prerequisites = prerequisites,
            effects = effects,
            unit = {
                count = 100 * i,
                ingredients = get_tech_ingredients(i * 2),
                time = math.min(60, 15 * i)
            },
            upgrade = true
        }
        table.insert(extensions, depth_tech)
    end
end

local max_depth = 0
for _, ammo_name in ipairs(ammo_list) do
    local ammo = data.raw.ammo[ammo_name] or data.raw.item[ammo_name] or data.raw.capsule[ammo_name]
    max_depth = math.max(max_depth, for_capsules(ammo, {}, 0, settings.startup['capsule-ammo-combination-levels'].value))
end
if TECH_BASE then depth_techs(max_depth) end

-- log(serpent.block(depth_techs))

-- local orders_table = {}
-- for i, prototype in ipairs(shorten_order_string) do
--     orders_table[prototype.order] = true
-- end
-- local dedup_orders_list = {}
-- for k, _ in pairs(orders_table) do
--     table.insert(dedup_orders_list, k)
-- end
-- local len = math.ceil(math.log(#dedup_orders_list + 1)/math.log(10))
-- log('#shorten_order_string: '..#shorten_order_string)
-- log('#dedup_orders_list: '..#dedup_orders_list)
-- log('len: '..len)
-- table.sort(dedup_orders_list, function(a, b) return a < b end)
-- local map_order_to_index = {}
-- for i, order in ipairs(dedup_orders_list) do
--     map_order_to_index[order] = i
-- end
-- for i, prototype in ipairs(shorten_order_string) do
--     local old = prototype.order
--     prototype.order = leftpad0(map_order_to_index[prototype.order], len)
-- end
-- if true then
--     table.sort(shorten_order_string, function(a, b) return a.order < b.order end)
--     for _, prototype in ipairs(shorten_order_string) do
--         log(prototype.order..' '..prototype.name..' '..prototype.type)
--     end
-- end
-- for i, capsule in ipairs(capsule_list) do
--     log(serpent.block({i = i, name = capsule.name}))
-- end

-- log(serpent.block(data.raw['trigger-target-type']))
log('#extensions: '..#extensions)
-- log(serpent.block(extensions))

-- for i, v in ipairs(extensions) do
--     if v.type == 'technology' then 
--         log(v.name) 
--         -- log(v.type) 
--         -- log(serpent.block({i, v})) 
--     end
-- end
-- for i, v in ipairs(extensions) do
--     if v.type == 'projectile' then 
--         log(v.name) 
--         -- log(v.type) 
--         -- log(serpent.block({i, v})) 
--     end
-- end

if #extensions > 0 then data:extend(extensions) end
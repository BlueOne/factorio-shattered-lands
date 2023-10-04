local Util = require("scripts.util")

local noise = require("noise")
local terraformer = require("scripts.mapGenNoise")
local tne = noise.to_noise_expression

-- Rocks
------------------------------------------------------------------------

local function rock_peak_old(rectangle, influence)
    local peak =
    {
        noise_layer = "rocks",
        noise_octaves_difference = -2,
        noise_persistence = 0.75,
        influence = influence or 1
    }

    if rectangle ~= nil then
        local aux_center = (rectangle[2][1] + rectangle[1][1]) / 2
        local aux_range = math.abs(rectangle[2][1] - rectangle[1][1]) / 2
        local water_center = (rectangle[2][2] + rectangle[1][2]) / 2
        local water_range = math.abs(rectangle[2][2] - rectangle[1][2]) / 2

        peak["aux_optimal"] = aux_center
        peak["aux_range"] = aux_range
        peak["aux_max_range"] = water_range + 0.05

        peak["water_optimal"] = water_center
        peak["water_range"] = water_range
        peak["water_max_range"] = water_range + 0.05
    end
    return peak
end

local rock_peak = {
    noise_layer = "rocks",
    noise_octaves_difference = -2,
    noise_persistence = 0.75,
}


local function rock_autoplace_settings(coverage, max_probability, order_suffix, tile_restriction)
    return
    {
        order = "a[doodad]-a[rock]-" .. order_suffix,
        coverage = coverage,
        sharpness = 0.9,
        max_probability = max_probability,
        peaks = { rock_peak },
        tile_restriction = tile_restriction
    }
end


-- local normal_rock_peaks = {rock_peak{{0, 0.3}, {1, 1}}, --[[rock_peak({{0.5, 0.}, {1, 0.2}}, 1)]]}
-- local sand_rock_peaks = {rock_peak{{0, 0}, {0.4, 0.2}}}

local coverage = { ["rock-big"] = 0.07, ["rock-huge"] = 0.04, ["sand-rock-big"] = 0.1 }
local max_probability = { ["rock-big"] = 0.2, ["rock-huge"] = 0.2, ["sand-rock-big"] = 0.1 }

alien_biomes = alien_biomes or nil
if not alien_biomes then
    local sand_tiles = { "sand-1", "sand-2", "sand-3", "red-desert-0", "red-desert-1", "red-desert-2", "red-desert-3" }
    local not_sand_tiles = {}
    for _, tile in pairs(data.raw.tile) do
        if not Util.find(tile.name, sand_tiles) then
            table.insert(not_sand_tiles, tile.name)
        end
    end

    -- for _, prototype in pairs(data.raw["simple-entity"]) do
    --     if string.find(prototype.name, "rock") then
    --         prototype.autoplace.peaks = Util.copy(rock_peak)
    --         prototype.
    --     end
    -- end
    for _, rock_name in pairs({ "rock-big", "rock-huge", "sand-rock-big" }) do
        local prototype = data.raw["simple-entity"][rock_name]
        local cvg = coverage[rock_name]
        local max_pr = max_probability[rock_name]
        prototype.autoplace = rock_autoplace_settings(cvg, max_pr, "b[" .. rock_name .. "]", not_sand_tiles)
    end
else
    for _, rock_name in pairs({ "rock-big", "rock-huge", "sand-rock-big" }) do
        local cvg = coverage[rock_name]
        local max_pr = max_probability[rock_name]
        for name, _ in pairs({
            tan = { 193, 162, 127 },
            white = { 255, 255, 255 },
            grey = { 177, 183, 187 },
            black = { 135, 135, 135 },
            purple = { 169, 177, 239 },
            red = { 185, 107, 105 },
            violet = { 165, 107, 161 },
            dustyrose = { 180, 148, 137 },
            cream = { 234, 216, 179 },
            brown = { 162, 117, 88 },
            beige = { 178, 164, 138 },
            aubergine = { 126, 115, 156 }
        }) do
            local prototype_name = rock_name .. '-' .. name
            local prototype = data.raw["simple-entity"][prototype_name]
            if prototype then
                prototype.autoplace.coverage = cvg
                prototype.autoplace.sharpness = 0.9
                prototype.autoplace.max_probability = max_pr
                prototype.autoplace.peaks = { rock_peak }
            end
        end
    end
end


-- Abyss
------------------------------------------------------------------------

data:extend({
    {
        type = "autoplace-control",
        name = "abyss",
        order = "z-a",
        category = "terrain",
        richness = true,
    },
    {
        type = "noise-expression",
        name = "control-setting:abyss:frequency:multiplier",
        expression = tne(1)
    },
    {
        type = "noise-expression",
        name = "control-setting:abyss:bias",
        expression = tne(0)
    },

})

-- Noise Expression
data:extend
{
    {
        type = "noise-expression",
        name = "abyss-elevation",
        expression = noise.define_noise_function(
            function(x, y, tile, _map)
                -- Hot gargage hack to make this independent of water properties
                -- TODO: Link to settings sliders
                local map = Util.copy(_map)
                map.segmentation_multiplier = noise.get_control_setting("abyss").frequency_multiplier
                map.wlc_elevation_offset = noise.get_control_setting("abyss").size_multiplier
                return terraformer.island_web_world(x, y, tile, map)
            end)
    }
}

-- Tile and Autoplace
local function make_water_autoplace_settings(max_elevation, influence)
    local elevation = noise.var("abyss-elevation")
    local fitness = max_elevation - elevation
    -- Adjust fitness to allow higher-influence (usually deeper) water to override shallower water,
    -- even at elevations where they both have >0 fitness
    local adjusted_fitness = influence * noise.min(fitness, 1)
    return {
        -- If fitness is < 0, probability will be -infinity,
        -- so that water doesn't override the default walkable tile (in case no other tile is placed).
        -- Otherwise probability is adjusted_fitness:
        probability_expression = noise.min(fitness * math.huge, adjusted_fitness)
    }
end

local abyss_tile = Util.copy(data.raw.tile["out-of-map"])
abyss_tile.name = "abyss"
abyss_tile.order = "aa"
abyss_tile.autoplace = make_water_autoplace_settings(0, 300)
abyss_tile.transition_merges_with_tile = "out-of-map"
abyss_tile.map_color = { 0.1, 0.1, 0.1 }
-- collision mask is set in final-fixes, for compatibility with hovercraft mod
-- Util.remove_from_table(abyss_tile.collision_mask, "water-tile")
data:extend { abyss_tile }


-- Preset
------------------------------------------------------------------------
local preset = { order = "a" }

local autoplace_controls = {}
for resource_name, resource in pairs(data.raw.resource) do
    if resource.autoplace then
        autoplace_controls[resource_name] = { frequency = 2, size = 0.5 }
    end
end
autoplace_controls.trees = { frequency = 0.8, size = 0.85 }

preset.basic_settings = {
    autoplace_controls = autoplace_controls,
    terrain_segmentation = 3,
    cliff_settings = { richness = 50, cliff_elevation_interval = 0.1 }
}

local preset_collection = data.raw["map-gen-presets"].default
preset_collection["shattered-land"] = preset
preset_collection.default.order = "ab"


-- Menu Simulations
------------------------------------------------------------------------
local menu_simulations = data.raw["utility-constants"]["default"].main_menu_simulations

local function edit_simulation(name, script_name)
    if menu_simulations[name] then
        menu_simulations[name].save = "__shattered-lands__/menu-simulations/menu-simulation-" ..
        script_name .. "-edited.zip"
    end
end
for name, script_name in pairs({
    artillery = "artillery",
    big_defense = "big-defense",
    burner_city = "burner-city",
    chase_player = "chase-player",
    logistic_robots = "logistic-robots",
    solar_power_construction = "solar-power-construction",
    spider_ponds = "spider-ponds",
    nuclear_power = "nuclear-power",
    early_smelting = "early-smelting",
    train_junction = "train-junction",
    mining_defense = "mining-defense",
    oil_pumpjacks = "oil-pumpjacks",
    brutal_defeat = "brutal-defeat"
}) do
    edit_simulation(name, script_name)
end


-- Integration of other mods
------------------------------------------------------------------------

-- Hovercraft
local hovercraft_tech = data.raw.technology["hcraft-tech"]
if hovercraft_tech then
    hovercraft_tech.prerequisites = {
        "automobilism",
        "fluid-handling"
    }
    hovercraft_tech.unit =
    {
        count = 50,
        ingredients =
        {
            { name = "automation-science-pack", amount = 1 },
            { name = "logistic-science-pack", amount = 1 }
        },
        time = 30
    }
    data.raw.recipe["hcraft-recipe"].ingredients = {
        { name = "steel-plate",      amount = 5 },
        { name = "iron-gear-wheel",  amount = 8 },
        { name = "engine-unit",      amount = 10 },
        { name = "electronic-circuit", amount = 10 }
    }
end


-- Teleporter
local bulk_tele_tech = data.raw.technology["bulkteleport-tech1"]
if bulk_tele_tech then
    bulk_tele_tech.prerequisites = {
        "electric-energy-accumulators",
        "circuit-network",
        "utility-science-pack",
    }
    bulk_tele_tech.unit =
    {
        count = 500,
        ingredients =
        {
            { name = "automation-science-pack", amount = 1 },
            { name = "logistic-science-pack", amount = 1 },
            { name = "chemical-science-pack", amount = 1 },
            { name = "utility-science-pack",  amount = 1 },
            { name = "production-science-pack", amount = 1 },
        },
        time = 30
    }
    local bulk_tele_tech2 = data.raw.technology["bulkteleport-tech2"]
    bulk_tele_tech2.enabled = false
    bulk_tele_tech2.hidden = true

    local bulk_teleporter_sender_buffer = data.raw.container["bulkteleport-buffer-send1"]
    bulk_teleporter_sender_buffer.inventory_size = 40
    local bulk_teleporter_receiver_buffer = data.raw.container["bulkteleport-buffer-recv1"]
    bulk_teleporter_receiver_buffer.inventory_size = 60
    local bulk_teleporter_energizer_send = data.raw.furnace["bulkteleport-energizer-send1"]
    bulk_teleporter_energizer_send.energy_usage = "60MW" -- should use 10MW per belt
    local bulk_teleporter_energizer_receive = data.raw.furnace["bulkteleport-energizer-recv1"]
    bulk_teleporter_energizer_receive.energy_usage = "60MW"
end


-- Lex's Airships
-- unlock the airplanes later and make the recipes more like spidertron recipes (higher tech items, lower amounts)
local jet_engine_tech = data.raw.technology["lex-jet-engine"]
if jet_engine_tech then
    local gunship_tech = data.raw.technology["lex-flying-gunship-ships"]
    local cargo_ship_tech = data.raw.technology["lex-flying-cargo-ships"]
    local heavy_gunship_tech = data.raw.technology["lex-flying-heavyship-ships"]
    local spidertron_tech = data.raw.technology.spidertron
    if jet_engine_tech then
        jet_engine_tech.unit = {
            count = 200,
            ingredients =
            {
                { name = "automation-science-pack", amount = 1 },
                { name = "logistic-science-pack", amount = 1 },
                { name = "chemical-science-pack", amount = 1 },
                { name = "utility-science-pack",  amount = 1 },
            },
            time = 30
        }
    end
    if cargo_ship_tech then
        cargo_ship_tech.unit = {
            count = 300,
            ingredients =
            {
                { name = "automation-science-pack", amount = 1 },
                { name = "logistic-science-pack", amount = 1 },
                { name = "chemical-science-pack", amount = 1 },
                { name = "utility-science-pack",  amount = 1 },
            },
            time = 30
        }
    end
    if gunship_tech then
        gunship_tech.unit = {
            count = 600,
            ingredients =
            {
                { name = "automation-science-pack", amount = 1 },
                { name = "logistic-science-pack", amount = 1 },
                { name = "chemical-science-pack", amount = 1 },
                { name = "military-science-pack", amount = 1 },
                { name = "utility-science-pack",  amount = 1 },
            },
            time = 30
        }
    end
    if heavy_gunship_tech then heavy_gunship_tech.unit.time = 60 end
    if spidertron_tech then
        spidertron_tech.unit =
        {
            count = 500,
            ingredients =
            {
                { name = "automation-science-pack", amount = 1 },
                { name = "logistic-science-pack", amount = 1 },
                { name = "chemical-science-pack", amount = 1 },
                { name = "utility-science-pack",  amount = 1 },
                { name = "production-science-pack", amount = 1 }
            },
            time = 30
        }
    end
    local flying_cargo_recipe = data.raw.recipe["lex-flying-cargo"]
    flying_cargo_recipe.ingredients = {
        { name="raw-fish",              amount=1 },
        { name="rocket-control-unit",   amount=10 },
        { name="low-density-structure", amount=100 },
        { name="flying-robot-frame",    amount=30 },
        { name="radar",                 amount=2 }
    }
    flying_cargo_recipe.normal.ingredients = flying_cargo_recipe.ingredients
    table.insert(cargo_ship_tech.prerequisites, "rocket-control-unit")
    local flying_gunship_recipe = data.raw.recipe["lex-flying-gunship"]
    flying_gunship_recipe.ingredients = {
        { name="raw-fish",              amount=1 },
        { name="low-density-structure", amount=20 },
        { name="steel-plate",           amount=100 },
        { name="flying-robot-frame",    amount=10 },
        { name="submachine-gun",        amount=2 },
        { name="rocket-launcher",       amount=2 },
        { name="radar",                 amount=1 }
    }
    flying_gunship_recipe.normal.ingredients = flying_gunship_recipe.ingredients
    local heavy_gunship_recipe = data.raw.recipe["lex-flying-heavyship"]
    heavy_gunship_recipe.ingredients = {
        { name="raw-fish",              amount=1 },
        { name="low-density-structure", amount=50 },
        { name="steel-plate",           amount=250 },
        { name="flying-robot-frame",    amount=20 },
        { name="rocket-launcher",       amount=10 },
        { name="tank",                  amount=2 },
        { name="radar",                 amount=2 }
    }
    heavy_gunship_recipe.normal.ingredients = heavy_gunship_recipe.ingredients
end

-- Spidertron Patrols
-- data.raw["spider-vehicle"]["sp-spiderling"] = nil
-- create_spidertron{
--     name = "sp-spiderling",
--     scale = 0.7,
--     leg_scale = 0.75, -- relative to scale
--     leg_thickness = 1.2, -- relative to leg_scale
--     leg_movement_speed = 0.62
-- }
-- create_spidertron{
--     name = "sp-spiderling",
--     scale = 0.8,
--     leg_scale = 0.9, -- relative to scale
--     leg_thickness = 1.2, -- relative to leg_scale
--     leg_movement_speed = 0.8
-- }
local spiderling_recipe = data.raw.recipe["sp-spiderling"]
if spiderling_recipe then
    spiderling_recipe.ingredients = {
        { "raw-fish",              1 },
        { "steel-plate",           50 },
        { "copper-plate",          200 },
        { "effectivity-module-2",  2 },
        { "exoskeleton-equipment", 2 },
        { "radar",                 1 },
    }
end

-- Thrower inserter
-- local thrower_tech = data.raw.technology["thrower-inserter"]
-- if thrower_tech then
--     thrower_tech.prerequisites = {

--     }
-- end



-- Scrap Processing 2
if data.raw.technology["scrap-processing"] then
    data.raw.item["military-scrap"].stack_size = 2000
end

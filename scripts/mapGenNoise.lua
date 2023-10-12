-- Heavily modified, starting from Sparkletron's Terraformers https://mods.factorio.com/mod/Sparkletrons_Terraformers

local noise = require("noise")
local util = require("scripts.mapGenUtil")

local mapGenDefault = require("scripts.mapGenDefault")


local tne = noise.to_noise_expression
local abs = noise.absolute_value
local max = noise.max
local min = noise.min


local function island_map(x,y,tile,map,options)
  options = options or {}
  x = x * map.segmentation_multiplier + 10000 -- Move the point where 'fractal similarity' is obvious off into the boonies
  y = y * map.segmentation_multiplier

  local terrain_octaves =  8
  local amplitude_multiplier = 1/8
  local roughness_persistence = 0.7

  local roughness = mapGenDefault.simple_amplitude_corrected_multioctave_noise{
    x = x,
    y = y,
    seed0 = map.seed,
    seed1 = 1,
    octave_count = terrain_octaves - 2,
    amplitude = 1/2,
    octave0_input_scale = 1/2,
    persistence = roughness_persistence
  }
    -- persistence = options.persistence_max or persistence

  local persistence = roughness * 0.1 + 0.65 -- between 0.6 and 0.7
  local island_map = mapGenDefault.simple_variable_persistence_multioctave_noise{
    x = x,
    y = y,
    seed0 = map.seed,
    seed1 = 2,
    octave_count = terrain_octaves,
    octave0_input_scale = options.input_scale or (1/2),
    octave0_output_scale = amplitude_multiplier,
    persistence = persistence
  }

  island_map = island_map + max(200 / map.segmentation_multiplier - tile.distance, 0)
  return abs(island_map) - 5 + (options.water_offset or -map.wlc_elevation_offset * 12)
end


local function bridge_width_multiplier()
  -- This is the 'coverage' slider
  local s = noise.get_control_setting("abyss-bridges").size_multiplier
  s = noise.less_than(s,1)/(-s) + (1-noise.less_than(s,1))*s*s
  s = (s + 6) / 11
  -- s = noise.clamp((s+6) / 11,0,1)
    -- 0 < s < 1
  return s
end


local function bridge_map(x,y,tile,map)
  x = x / noise.get_control_setting("abyss-bridges").frequency_multiplier / 20 + 10000 -- Move the point where 'fractal similarity' is obvious off into the boonies
  y = y / noise.get_control_setting("abyss-bridges").frequency_multiplier / 20

  local bridges = mapGenDefault.simple_amplitude_corrected_multioctave_noise{
    x = x,
    y = y,
    seed0 = map.seed,
    seed1 = 8,
    octave_count = 3,
    amplitude = 2,
    octave0_input_scale = 1/2,
    persistence = 0.3
  }

  -- Add rougher edges
  local bridge_noise = mapGenDefault.simple_amplitude_corrected_multioctave_noise{
    x = x,
    y = y,
    seed0 = map.seed,
    seed1 = 9,
    octave_count = 3,
    amplitude = 0.2,
    octave0_input_scale = 20,
    persistence = 0.6
  }
  bridges = bridges + bridge_noise / 2

  local bridge_threshold = bridge_width_multiplier() / 5

  return noise.less_than(abs(bridges), bridge_threshold)
end

local function crumbled_bridge_width_multiplier()
  -- This is the 'coverage' slider
  local s = noise.get_control_setting("abyss-crumbled-bridges").size_multiplier
  s = noise.less_than(s,1)/(-s) + (1-noise.less_than(s,1))*s*s
  s = (s+6) / 11
  -- s = noise.clamp((s+6) / 11,0,1)
  return s
end


local function crumbled_bridges(x,y,tile,map,options)
  x = x / noise.get_control_setting("abyss-crumbled-bridges").frequency_multiplier / 20 + 10000 -- Move the point where 'fractal similarity' is obvious off into the boonies
  y = y / noise.get_control_setting("abyss-crumbled-bridges").frequency_multiplier / 20

  local bridges = mapGenDefault.simple_amplitude_corrected_multioctave_noise{
    x = x,
    y = y,
    seed0 = map.seed,
    seed1 = 10,
    octave_count = 3,
    amplitude = 1.7,
    octave0_input_scale = 1/2,
    persistence = 0.3
  }

  local noise1 = mapGenDefault.simple_amplitude_corrected_multioctave_noise{
    x = x,
    y = y,
    seed0 = map.seed,
    seed1 = 11,
    octave_count = 3,
    amplitude = 0.1,
    octave0_input_scale = 10,
    persistence = 0.9
  }

  local noise2 = mapGenDefault.simple_amplitude_corrected_multioctave_noise{
    x = x,
    y = y,
    seed0 = map.seed,
    seed1 = 12,
    octave_count = 3,
    amplitude = 0.3,
    octave0_input_scale = 30,
    persistence = 0.9
  }

  local bridge_threshold = crumbled_bridge_width_multiplier() / 10
  local mask = noise.less_than(abs(bridges + noise1), bridge_threshold)
  bridges = mask * noise2

  return noise.less_than(abs(bridges), 0.1)
end

local function island_web_world(x,y,tile,map)
  local island_map_part = island_map(x,y,tile,map)
  local bridge_map_part = bridge_map(x,y,tile,map)
  local crumbled_bridges_part = crumbled_bridges(x,y,tile,map)
  -- local elevation = bridge_map-1
  -- local elevation = max( river_map,  bridge_map +  (1 - bridge_map) * river_map)
  local elevation = max(island_map_part, bridge_map_part - 1, -crumbled_bridges_part)
  -- local elevation = max(river_map, bridge_map - 1)
  -- local elevation = river_map

  -- elevation = elevation / map.segmentation_multiplier
  -- elevation = noise.min(elevation, standard_starting_lake_elevation_expression)
  return max(elevation, map.wlc_elevation_minimum)
  -- return max(max(elevation, map.wlc_elevation_minimum), crumbled_bridges)
end

return {
  -- ocean_world = ocean_world,
  -- seafloor_world = seafloor_world,
  -- honeycomb = honeycomb,
  island_web_world = island_web_world,
  -- rivers_and_bridges_world = rivers_and_bridges_world,
  -- default_mimic = default_mimic,
  -- starting_plateau_basis = starting_plateau_basis,
  -- starting_lake_basis = starting_lake_basis,
  -- warped_smooth_seas = warped_smooth_seas,
  -- river_maze_world = river_maze_world
}


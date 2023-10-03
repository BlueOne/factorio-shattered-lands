-- From Sparkletron's Terraformers https://mods.factorio.com/mod/Sparkletrons_Terraformers

local noise = require("noise")
local util = require("scripts.mapGenUtil")

local mapGenDefault = require("scripts.mapGenDefault")


local tne = noise.to_noise_expression
local abs = noise.absolute_value
local max = noise.max
local min = noise.min


local function bridge_width_multiplier()
  -- This is the 'coverage' slider
  local s = noise.get_control_setting("abyss").size_multiplier
  s = noise.less_than(s,1)/(-s) + (1-noise.less_than(s,1))*s
  s = noise.clamp((s+6) / 11,0,1)
    -- 0 < s < 1
  return s
end

local function starting_lake_basis(x,y,tile,map,distance)
  distance = distance or noise.distance_from(x, y, noise.var("starting_lake_positions"), 1024)
  local starting_lake_basis = util.make_multioctave_noise_function2(
    map.seed,
    2,
    4,
    0.6
  )(x,y, 1/12, 4)
  local lake =  starting_lake_basis - 6 + distance / 4
  local lake_bool = noise.var("st-starting-lake-bool")
  return lake * lake_bool + 10000 * (1-lake_bool)
end

local function starting_lake_rough_basis(x,y,tile,map)
  local distance = noise.distance_from(x, y, noise.var("starting_lake_positions"), 1024)
  local starting_lake_basis = util.make_multioctave_noise_function2(
    map.seed,
    2,
    8,
    0.6
  )(x,y, 1, 4)
  local lake =  starting_lake_basis - 7 + distance / 5
  local lake_bool = noise.var("st-starting-lake-bool")
  return lake * lake_bool + 10000 * (1-lake_bool)
end


local function starting_plateau_basis_rough(x,y,tile,map,distance)
  distance = distance or tile.distance
  local starting_plateau_basis = util.make_multioctave_noise_function2(
    map.seed,
    2,
    15,
    0.7
  )(x,y, map.segmentation_multiplier * 4, 8)
  return starting_plateau_basis + 16 - distance * map.segmentation_multiplier / 24
end


local function starting_plateau_basis(x,y,tile,map,distance)
  distance = distance or tile.distance
  local starting_plateau_basis = util.make_multioctave_noise_function2(
    map.seed,
    2,
    6,
    0.9
  )(x,y, 1/128, 8)
  return starting_plateau_basis + 12 - distance * map.segmentation_multiplier / 15
end

local function ocean_world(x,y,tile,map)
  -- The tuned ocean/continent generator
  local basis_noise = util.make_multioctave_noise_function2(
    map.seed, --seed0
    5, --seed1
    15, --octaves
    0.6 -- persistence 
  )(x,y,
    map.segmentation_multiplier * 4, --inscale
    10 --outscale
  )
  basis_noise = basis_noise + 3 + map.wlc_elevation_offset / 5 
  basis_noise = util.scale_positive_value(basis_noise, 50 / map.segmentation_multiplier)
  basis_noise = max(basis_noise, starting_plateau_basis_rough(x,y,tile,map),map.wlc_elevation_minimum)
  return min(basis_noise, starting_lake_rough_basis(x,y,tile,map))
end

local function seafloor_world(x,y,tile,map)
  -- The tuned ocean/continent generator
  local basis_noise = util.make_multioctave_noise_function2(
    map.seed, --seed0
    6, --seed1
    6, --octaves
    0.7 -- persistence 
  )(x,y,
    map.segmentation_multiplier / 100, --inscale
    10 --outscale
  )
  basis_noise = basis_noise + 8 + map.wlc_elevation_offset / 5 
  basis_noise = util.scale_positive_value(basis_noise, 32 / map.segmentation_multiplier)
  basis_noise = max(basis_noise, starting_plateau_basis(x,y,tile,map),map.wlc_elevation_minimum)
  return min(basis_noise, starting_lake_basis(x,y,tile,map))
end

local function default_mimic(x,y,tile,map,distance,lake_distance)
  distance = distance or tile.distance
  local basis_noise = util.make_multioctave_noise_function2(
    map.seed, --seed0
    1, --seed1
    8, --octaves
    0.4 -- persistence
  )(x,y,
    map.segmentation_multiplier/4, --inscale
    5 --outscale
  )
  basis_noise = basis_noise + 3 + map.wlc_elevation_offset /8
  basis_noise = util.scale_positive_value(basis_noise, 32 / map.segmentation_multiplier)
  basis_noise = max(basis_noise, starting_plateau_basis(x,y,tile,map,distance), map.wlc_elevation_minimum)
  return min(basis_noise, starting_lake_basis(x,y,tile,map,lake_distance))
end


local function bridge_map_noise(x,y,tile,map)
  x = x * map.segmentation_multiplier / 20 + 10000 -- Move the point where 'fractal similarity' is obvious off into the boonies
  y = y * map.segmentation_multiplier / 20

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

  return bridges + bridge_noise / 2
end

local function bridge_map(x,y,tile,map)
  local bridge_threshold = bridge_width_multiplier() / 5
  local bridges = bridge_map_noise(x,y,tile,map)
  return noise.less_than(abs(bridges), bridge_threshold)
end

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
  local island_start = mapGenDefault.simple_variable_persistence_multioctave_noise{
    x = x,
    y = y,
    seed0 = map.seed,
    seed1 = 3,
    octave_count = terrain_octaves-2,
    octave0_input_scale = options.input_scale or (1/2),
    octave0_output_scale = amplitude_multiplier,
    persistence =  noise.clamp(persistence - 0.1, 0.1, 0.8)
  }

  -- local offset = options.land_offset or (32 - 32*noise.var("control-setting:abyss:frequency:multiplier"))
  -- island_map = max(island_map + offset, island_start + 32 - tile.distance * map.segmentation_multiplier / 8)
  island_map = island_map + max(200 / map.segmentation_multiplier - tile.distance, 0)
  return abs(island_map) - 5 + (options.water_offset or -map.wlc_elevation_offset * 12)
end

local function noisy_bridges(x,y,tile,map,options)
  x = x * map.segmentation_multiplier / 20 + 10000 -- Move the point where 'fractal similarity' is obvious off into the boonies
  y = y * map.segmentation_multiplier / 20

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

  local bridge_threshold = bridge_width_multiplier() / 10
  local mask = noise.less_than(abs(bridges + noise1), bridge_threshold)
  bridges = mask * noise2

  return noise.less_than(abs(bridges), bridge_threshold)
end

local function island_web_world(x,y,tile,map)
  local river_map = island_map(x,y,tile,map)
  local bridge_map = bridge_map(x,y,tile,map)
  local noisy_bridges = noisy_bridges(x,y,tile,map)
  -- local elevation = bridge_map-1
  -- local elevation = max( river_map,  bridge_map +  (1 - bridge_map) * river_map)
  local elevation = max(river_map, bridge_map - 1, -noisy_bridges)
  -- local elevation = max(river_map, bridge_map - 1)
  -- local elevation = river_map

  -- elevation = elevation / map.segmentation_multiplier
  -- elevation = noise.min(elevation, standard_starting_lake_elevation_expression)
  return max(elevation, map.wlc_elevation_minimum)
  -- return max(max(elevation, map.wlc_elevation_minimum), noisy_bridges)
end

local function river_maze_world(x,y,tile,map)
  local s = noise.var("control-setting:abyss:frequency:multiplier")
  s = noise.less_than(s,1)/(-s) + (1-noise.less_than(s,1))*s
  s = 1 - noise.clamp((s+6) / 11,0,1)
  local river_map = island_map(x,y,tile,map,{
    persistence_max = util.lerp(0.05,0.7,s), -- 0.15 + 0.3 * noise.var("control-setting:st-terrastructure:frequency:multiplier"),
    persistence_bias = util.lerp(0.0,0.5,s), -- 0.15 + 0.3 * noise.var("control-setting:st-terrastructure:frequency:multiplier"),
    land_offset = 20,
    water_offset = map.wlc_elevation_offset * 0.6 + 2,
    input_scale = 1
  })
  local elevation = river_map

  -- elevation = elevation / map.segmentation_multiplier
  -- elevation = noise.min(elevation, standard_starting_lake_elevation_expression)
  return max(elevation, map.wlc_elevation_minimum)
end

local function warped_smooth_seas(x,y,tile,map)
  local warp_coords = util.warp_coordinates(x,y,tile,map)
  x = warp_coords.x
  y = warp_coords.y
  return seafloor_world(x,y,tile,map)
end



return {
  ocean_world = ocean_world,
  seafloor_world = seafloor_world,
  -- honeycomb = honeycomb,
  island_web_world = island_web_world,
  -- rivers_and_bridges_world = rivers_and_bridges_world,
  default_mimic = default_mimic,
  starting_plateau_basis = starting_plateau_basis,
  starting_lake_basis = starting_lake_basis,
  warped_smooth_seas = warped_smooth_seas,
  river_maze_world = river_maze_world
}


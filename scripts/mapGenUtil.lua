-- From Sparkletron's Terraformers https://mods.factorio.com/mod/Sparkletrons_Terraformers

local noise = require("noise")

local tne = noise.to_noise_expression
local abs = noise.absolute_value
local max = noise.max
local min = noise.min

local function lerp( v0, v1, t) 
  return (1 - t) * v0 + t * v1;
end

local function smoothstep(v0, v1, t)
  t = noise.clamp((t - v0) / (v1 - v0), 0.0, 1.0); 
  return t * t * (3 - 2 * t)
end

local function modulo(val, range)
    range = noise.absolute_value(range or 1)
    local quotient = val / range
    return (quotient - noise.floor(quotient)) * range -- noise.fmod(val, range)
end


-- its a step function, but instead of vertical steps, the steps are at 45 degrees.
-- the inclines are 'width' wide. The platforms are 'spacing-width' wide 
local function slope_step(x,width,spacing)
  local mod_x = modulo(x,spacing)
  local step_num = noise.floor(x / spacing)
  local cond = noise.less_than(mod_x, width)
  return step_num * width + mod_x * cond + width * (1-cond)
end


local function hard_step(x,width,height)
  return height * noise.floor( x / width )
end


-- We can't do square roots here so this approximation will have to do
local function distance( x, y, x1, y1)
  -- https://www.flipcode.com/archives/Fast_Approximate_Distance_Functions.shtml
  local dx = abs(x-x1)
  local dy = abs(y-y1)
  local min = noise.min(dx,dy)
  local max = noise.max(dx,dy)
  local approx = (max * 1007) + min*441
  approx = approx - noise.less_than(max, min*16) * max * 40
  return (approx + 512) / 1024
end

-- dx=5,dy=2
-- manhattan = 7
-- (5*1077+2*441+512)/1024  = 6.6201171875
-- (5*1077+2*441+512-5*40)/1024 = 6.4248046875 
-- pythagorean = sqrt(25+4) = 5.3851648071

-- dx = 30, dy - 30
-- manhattan = 60
-- (30*1077+30*441+512)/1024 = 44.97265625
-- (30*1077+30*441+512-30*40)/1024 = 43.80078125
-- pythagorean = 42.4264068712
-- pretty good!

local function make_multioctave_noise_function(seed0,seed1,octaves,octave_output_scale_multiplier,octave_input_scale_multiplier,output_scale0,input_scale0)
  octave_output_scale_multiplier = octave_output_scale_multiplier or 2
  octave_input_scale_multiplier = octave_input_scale_multiplier or (1 / octave_output_scale_multiplier)
  return function(x,y,inscale,outscale)
    return tne{
      type = "function-application",
      function_name = "factorio-quick-multioctave-noise",
      arguments =
      {
        x = tne(x),
        y = tne(y),
        seed0 = tne(seed0),
        seed1 = tne(seed1),
        input_scale = tne((inscale or 1) * (input_scale0 or 1)),
        output_scale = tne((outscale or 1) * (output_scale0 or 1)),
        octaves = tne(octaves),
        octave_output_scale_multiplier = tne(octave_output_scale_multiplier),
        octave_input_scale_multiplier = tne(octave_input_scale_multiplier)
      }
    }
  end
end

local function make_multioctave_noise_function2(seed0,seed1,octaves,persistence)
  return function(x,y,inscale,outscale)
    return tne{
      type = "function-application",
      function_name = "factorio-multioctave-noise",
      arguments =
      {
        x = tne(x),
        y = tne(y),
        seed0 = tne(seed0),
        seed1 = tne(seed1),
        input_scale = tne((inscale or 1)),
        output_scale = tne((outscale or 1)),
        octaves = tne(octaves),
        persistence = tne(persistence)
      }
    }
  end
end

local minimal_starting_lake_elevation_expression = noise.define_noise_function( function(x,y,tile,map)
  local starting_lake_distance = noise.distance_from(x, y, noise.var("starting_lake_positions"), 1024)
  local minimal_starting_lake_depth = 4
  local lake_noise = tne{
    type = "function-application",
    function_name = "factorio-basis-noise",
    arguments = {
      x = x,
      y = y,
      seed0 = tne(map.seed),
      seed1 = tne(123),
      input_scale = noise.fraction(1,8),
      output_scale = tne(1.5)
    }
  }
  local minimal_starting_lake_bottom =
    starting_lake_distance / 4 - minimal_starting_lake_depth + lake_noise

  return minimal_starting_lake_bottom
end)


-- used to scale the sliders in the mapgen gui
-- scaling is 0..1. 0 is ignore slider. 1 is fully use slider value
local function scale_slider(value,scaling)
  return 1 - scaling + value*scaling
end

local function scale_positive_value(x,y)
  return noise.min(x,x*y)
end

local function round(x)
  local floor = noise.floor(x)
  local clause = noise.less_than(x - floor, 0.5)
  return clause*floor + (1-clause)*(floor+1)
end


-- Algorithms adapted from https://www.redblobgames.com/grids/hexagons/
-- Some of the hex modes have bad co-efficients
-- But the larger issues are:
-- 1. It is difficult to accomodate 4 hex modes in the map gen UX without combinitorial explosion
-- 2. The 45 degree modes still use 60ish degree bridges, meaning you still can't use 45 degree rails.
-- 2a. This is more apparent with wide moats between hexagons.
local function hex_coord_for_point(x,y,hex_size,hex_mode)
  hex_mode = hex_mode or "hex-reg-flat"
  if hex_mode == "hex-reg-flat" then -- Flat top 60
    return {
      q = (x * 2 / 3) / hex_size,
      r =  (-x / 3 + 0.5773502692 * y) / hex_size
    }
  elseif hex_mode == "hex-reg-pointy" then -- Pointy top 60 
    return {
      q = (0.5773502692 * x + y/3) / hex_size,
      r = (2 / 3 * y) / hex_size
    }
  elseif hex_mode == "hex-45-flat"  then -- Flat top 90
    return {
      q = (0.4142135624 * x) / hex_size,
      r = (0.2071067812 * x + y / 2) / hex_size
    }  
  else
    return {
      q = (x / 2 - 0.2071067812 * y ) / hex_size,
      r = (0.4142135624 * y) / hex_size
    }
  end 
end

local function hex_center_for_qr(q,r,hex_size,hex_mode)
  hex_mode = hex_mode or "hex-reg-flat"
  if hex_mode == "hex-reg-flat" then -- Flat top 60
    return {
      x = hex_size * (3 / 2 * q),
      y = hex_size * (0.8660254038 * q + 1.7320508076 * r)
    }
  elseif hex_mode == "hex-reg-pointy" then -- Pointy top 60 
    return {
      x = hex_size * (1.7320508076 * q + 0.8660254038 * r),
      y = hex_size * (3 / 2 * r)
    }
  elseif hex_mode == "hex-45-flat"  then -- Flat top 90
    return {
      x = hex_size * (2.4142135624 * q),
      y = hex_size * (    q + 2 * r)
    }
  else
    return {
      x = hex_size * (2 * q + r),
      y = hex_size * (2.4142135624 * r)
    }
  end    
end

local function hex_round( hex )
  local x = hex.q
  local z = hex.r
  local y = - x - z

  local rx = round(x)
  local ry = round(y)
  local rz = round(z)

  local x_diff = abs( rx - x )
  local y_diff = abs( ry - y )
  local z_diff = abs( rz - z )

  local clause1 =noise.less_than(y_diff, x_diff) * noise.less_than(z_diff, x_diff) 
  rx = clause1 * (-ry - rz) + (1 - clause1 ) * rx
  local clause2 = noise.less_than(z_diff, y_diff) * (1-clause1)
  ry = clause2 * (-rx -rz) + (1-clause2) * ry
  rz = (1 - clause2 ) * (-rx -ry) + clause2 * rz

  return {q = rx, r = rz}
end

local function cube_distance_to_hex_center( q, r, qc, rc)
  local x = q
  local z = r
  local y = - x - z

  local xc = qc
  local zc = rc
  local yc = - xc - zc

  local a = abs(xc-x)
  local b = abs(zc-z)
  local c = abs(yc-y)

  return max( a+b, b+c, c+a)
end

local function distance_to_hex_cube_axis( q, r, qc, rc)
  local x = q
  local z = r
  local y = - x - z

  local xc = qc
  local zc = rc
  local yc = - xc - zc

  local a = abs(xc-x)
  local b = abs(zc-z)
  local c = abs(yc-y)

  return min( a, b, c)
end

local function raise_hex_rings(q,r,raise)
  local condition = noise.less_than(noise.fmod(abs(q), 2) * noise.fmod(abs(r),2),1)
  return condition*raise
end

local function water_level_correct(to_be_corrected, map)
  return noise.max(
    map.wlc_elevation_minimum,
    to_be_corrected + map.wlc_elevation_offset
  )
end

local function starting_plateau(m)
        -- Create a starting plateau. This will gaurantee an island start or a better coastal start.
      -- Sometimes it will fill in lakes and stuff on a good continental starting_elevation_bump

      local d = noise.clamp(m,0.5,2) * noise.var("distance")
      return noise.clamp(60 * noise.atan2(tne(120),d) - d/40, 0, 40)
      -- todo: create islands that are not centered on the player/ have direction
end

local function warp(x,y,map,seed,options)
  options = options or {}
  local warp = make_multioctave_noise_function2(
    map.seed, --seed0
    seed, --seed1
    6, --octaves
    0.7 -- persistence 
  )(x,y,
    -- map.segmentation_multiplier / 400, --inscale
    options.inscale or (1/400), --inscale
    100 --outscale
  )
  return warp
end

local function warp_coordinates(x,y,tile,map,options)
  local warp_level = noise.var("st-warp-mode")

  -- Protect the starting area by reducing magnitude of warp field near origin
  local field_suppressor = smoothstep(0,1, (tile.distance - 60) / 400)
  warp_level = warp_level * field_suppressor

  local warp_x = warp_level * warp(x,y,map,1,options)
  local warp_y = warp_level * warp(x,y,map,2,options)
  return {  
    x = x + warp_x,
    y = y + warp_y
  }
end


local function square_coord(x,y,square_size)
  return {
    x = round(x/square_size),
    y = round(y/square_size)
  }
end

local function square_center(x,y,square_size)
  return {
    x = round(x/square_size) * square_size,
    y = round(y/square_size) * square_size
  }
end

local function manhattan_distance_to_square_center(x,y,cx,cy)
  return abs(x-cx) + abs(y-cy)
end

local function distance_to_square_axis(x,y,cx,cy)
  return min(abs(x-cx),abs(y-cy))
end


return {
  lerp = lerp,
  smoothstep = smoothstep,
  slope_step = slope_step,
  hard_step = hard_step,
  distance = distance,
  raise_hex_rings = raise_hex_rings, -- should probably move out of util
  cube_distance_to_hex_center = cube_distance_to_hex_center,
  hex_round = hex_round,
  hex_center_for_qr = hex_center_for_qr,
  hex_coord_for_point = hex_coord_for_point,
  scale_slider = scale_slider,
  make_multioctave_noise_function2 = make_multioctave_noise_function2,
  minimal_starting_lake_elevation_expression = minimal_starting_lake_elevation_expression,
  water_level_correct = water_level_correct,
  starting_plateau = starting_plateau,
  distance_to_hex_cube_axis = distance_to_hex_cube_axis,
  warp = warp,
  warp_coordinates = warp_coordinates,
  square_center = square_center,
  square_coord = square_coord,
  manhattan_distance_to_square_center = manhattan_distance_to_square_center,
  distance_to_square_axis = distance_to_square_axis,
  scale_positive_value = scale_positive_value
}


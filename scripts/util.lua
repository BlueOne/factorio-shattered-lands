
local Util = {}
local util = require("__core__/lualib/util.lua")


-- Ruins spawning etc.
-----------------------------------------------------------


function Util.custom_insert_safe (entity, item_dict)
  if not (entity and entity.valid and item_dict) then return end

  local insert = entity.insert
  for name, count in pairs (item_dict) do
    -- check if the item exists
    local item_type = Util.cached_item_type(name)
    if item_type then
      insert{name = name, count = count}
    end
  end
end 

function Util.insert_fluid_safe(entity, fluid_dict)
  if not (entity and entity.valid and fluid_dict) then return end
  local fluids = game.fluid_prototypes
  local insert = entity.insert_fluid
  for name, amount in pairs (fluid_dict) do
    if fluids[name] then
      insert{name = name, amount = amount}
    else
      log("Fluid to insert not valid: " .. name)
    end
  end
end


function Util.insert_loot(containers, loot_table)
  -- check if all containers are valid
  local valid_containers = {}
  for _, container in pairs(containers) do
    if container.valid then table.insert(valid_containers, container) end
  end

  for _, item_stack in pairs(loot_table) do
    local container = Util.random_choice_array(containers)
    container.insert(item_stack)
  end
end

-- Cached API calls
-----------------------------------------------------------

function Util.entity_type(name)
  if game.entity_prototypes[name] then return game.entity_prototypes[name].type end
  return false
end

function Util.item_type(name)
  return game.item_prototypes[name] and game.item_prototypes[name].type or false
end

function Util.remnant_names(name)
  local prototype = game.entity_prototypes[name]
  if not prototype then
    return false
  else
    return Util.keys(prototype.corpses or {})
  end
end

function Util.entity_prototype_selection_box(name)
  local prototype = game.entity_prototypes[name]
  if not prototype then return false end
  return prototype.selection_box
end

function Util.cached(fn, cache)
  local f = function(input)
    local cached_result = cache[input]
    if cached_result ~= nil then return cached_result end
    local result = fn(input)
    cache[input] = result
    return result
  end
  return f
end

local entity_selection_box_cache = {}
Util.cached_entity_selection_box = Util.cached(Util.entity_prototype_selection_box, entity_selection_box_cache)

local entity_type_cache = {}
Util.cached_entity_type = Util.cached(Util.entity_type, entity_type_cache)

local item_type_cache = {}
Util.cached_item_type = Util.cached(Util.item_type, item_type_cache)

local remnant_cache = {}
Util.cached_remnant_names = Util.cached(Util.remnant_names, remnant_cache)



-- Geometry
-----------------------------------------------------------

function Util.random_point_in_rect(rect, generator)
  generator = generator or math.random
  local x
  local y
  x = generator(rect.left_top.x, rect.right_bottom.x)
  y = generator(rect.left_top.y, rect.right_bottom.y)
  return { x = x, y = y }
end


function Util.is_proper_rect(rect)
  return rect.left_top.x < rect.right_bottom.x and rect.left_top.y < rect.right_bottom.y
end


function Util.intersect_aabb(rect1, rect2)
  for _, k in pairs({"x", "y"}) do
    if rect1.right_bottom[k] < rect2.left_top[k] or rect2.right_bottom[k] < rect1.left_top[k] then return false end
  end
  return true
end

function Util.direction_to_orientation(direction)
  if direction == defines.direction.north then
      return 0
  elseif direction == defines.direction.northeast then
      return 0.125
  elseif direction == defines.direction.east then
      return 0.25
  elseif direction == defines.direction.southeast then
      return 0.375
  elseif direction == defines.direction.south then
      return 0.5
  elseif direction == defines.direction.southwest then
      return 0.625
  elseif direction == defines.direction.west then
      return 0.75
  elseif direction == defines.direction.northwest then
      return 0.875
  end
  return 0
end

function Util.orientation_to_direction(orientation)
  orientation = (orientation + 0.0625) % 1
  if orientation <= 0.125 then
    return defines.direction.north
  elseif orientation <= 0.25 then
    return defines.direction.northeast
  elseif orientation <= 0.375 then
    return defines.direction.east
  elseif orientation <= 0.5 then
    return defines.direction.southeast
  elseif orientation <= 0.625 then
    return defines.direction.south
  elseif orientation <= 0.75 then
    return defines.direction.southwest
  elseif orientation <= 0.875 then
    return defines.direction.west
  else
    return defines.direction.northwest
  end
end



-- Remote interfaces
-----------------------------------------------------------

function Util.expose_remote_interface(module, name, function_names)
  local functions = {}
  for _, k in pairs(function_names) do
    local v = module[k]
    if type(v) == "function" then
      functions[k] = v
    end
  end
  remote.add_interface(name, functions)
end

function Util.expose_remote_interface_all(module, name)
  local functions = {}
  for k, v in pairs(module) do
    if type(v) == "function" then
      functions[k] = v
    end
  end
  Util.remote_add_interface(name, functions)
end


-- Stochastics
-----------------------------------------------------------

function Util.sample_poisson(lambda, generator)
  local r = generator()
  local el = math.exp(-lambda)
  local i_factorial = 1
  local lambda_pw = 1
  for i = 0, 4 do
      if i > 0 then i_factorial = i_factorial * i end
      local p = el * lambda_pw / i_factorial
      lambda_pw = lambda_pw * lambda
      if r >= 1 - p then return i end
      r = r + p
  end
  return 5
end



-- Tables
-----------------------------------------------------------

Util.compare = util.table.compare
Util.deepcopy = util.table.deepcopy
Util.copy = util.table.deepcopy
Util.merge = util.merge

function Util.table_size(t)
  local size = 0
  for _, _ in pairs(t) do
    size = size + 1
  end
  return size
end

function Util.keys(t)
  local keys = {}
  for k, _ in pairs(t) do
    table.insert(keys, k)
  end
  return keys
end

function Util.values(t)
  local values = {}
  for _, v in pairs(t) do
    table.insert(values, v)
  end
  return values
end

function Util.table_contains(t, v)
  for _, v1 in pairs(t) do
    if v1 == v then return true end
  end
  return false
end

-- Example calls:
-- find(elem, list)
-- find(elem, list, equal_func)
-- find(list, identifier_func)
-- Returns key, value or false.

function Util.find(arg1, arg2, arg3)
  -- find(list, identifier_func)
    if type(arg1) == "table" and type(arg2) == "function" then
      for k, v in pairs(arg1) do
        if arg2(v) then
          return k, v
        end
      end
      return false
    end
  
    -- find(elem, list)
    if not arg3 then
      if type(arg1) == "table" then
        arg3 = Util.compare
      else
        for k, other in pairs(arg2) do
          if arg1 == other then
            return k, other
          end
        end
        return false
      end
    end
  
    -- find(elem, list, equal_func)
    for k, other in pairs(arg2) do
      if arg3(arg1, other) then
        return k, other
      end
    end
    return false
  end
  

function Util.find_minimum(list, lessthan_func)
	if #list == 0 then return 0 end
	local index = 1
	local min_value = list[index]
	for i, value in ipairs(list) do
		if lessthan_func then
			if lessthan_func(value, min_value) then
				index = i
				min_value = value
			end
		else
			if value < min_value then
				index = i
				min_value = value
			end
		end
	end
	return index, min_value
end


function Util.increment(t, k, v)
	if not t[k] then
		t[k] = v or 1
	else
		t[k] = t[k] + (v or 1)
	end
end

function Util.decrement(t, k, v)
	if not t[k] then
		t[k] = -(v or 1)
	else
		t[k] = t[k] - (v or 1)
	end
end


function Util.all_wrong(t)
  for _, v in pairs(t) do
    if v then return false end
  end
  return true
end

function Util.remove_from_table(list, item)
  local index = 0
  for _,_item in ipairs(list) do
      if item == _item then
          index = _
          break
      end
  end
  if index > 0 then
      table.remove(list, index)
  end
end



-- Randomness
function Util.random_choice_array(t, generator)
  generator = generator or math.random
  local count = #t
  local num = generator(count)
  return t[num]
end

function Util.random_choice_table(t, generator)
  generator = generator or math.random
  local count = Util.table_size(t)
  local num = generator(count)
  local key = next(t)
  while num > 1 do
    key = next(t, key)
    num = num - 1
  end

  return t[key], key
end

return util.merge{util, Util, util.table}

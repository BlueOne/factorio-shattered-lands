
-- Fix transitions with other tiles
for _, tile in pairs(data.raw.tile) do
    if tile.transitions then
        for _, transition in pairs(tile.transitions) do
            local out_of_map_found = false
            local abyss_found = false
            if transition.to_tiles then
                for _, tile_name in pairs(transition.to_tiles) do
                    if tile_name == "out-of-map" then
                        out_of_map_found = true
                    end
                    if tile_name == "abyss" then
                        abyss_found = true
                    end
                    if out_of_map_found and not abyss_found then
                        table.insert(transition.to_tiles, "abyss")
                        transition.transition_group = 2
                    end
                end
            end
        end
    end
end

data.raw.tile.abyss.layer = 0

if data.raw.car["hcraft-entity"] then
    local _, hovercraft_layer = next(data.raw.car["hcraft-entity"].collision_mask)
    table.insert(data.raw.tile.abyss.collision_mask, hovercraft_layer)
end

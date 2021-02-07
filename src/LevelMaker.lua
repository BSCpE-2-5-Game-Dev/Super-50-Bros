--[[
    GD50
    Super Mario Bros. Remake

    -- LevelMaker Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu
]]

LevelMaker = Class{}

function LevelMaker.generate(width, height)
    local tiles = {}
    local entities = {}
    local objects = {}

    local tileID = TILE_ID_GROUND
    
    -- whether we should draw our tiles with toppers
    local topper = true
    local tileset = math.random(20)
    local topperset = math.random(20)

    -- insert blank tables into tiles for later access
    for x = 1, height do
        table.insert(tiles, {})
    end

    -- column by column generation instead of row; sometimes better for platformers
    for x = 1, width do
        local tileID = TILE_ID_EMPTY
        
        -- lay out the empty space
        for y = 1, 6 do
            table.insert(tiles[y],
                Tile(x, y, tileID, nil, tileset, topperset))
        end

        -- chance to just be emptiness
        if math.random(7) == 1 then
            for y = 7, height do
                table.insert(tiles[y],
                    Tile(x, y, tileID, nil, tileset, topperset))
            end
        else
            tileID = TILE_ID_GROUND

            -- height at which we would spawn a potential jump block
            local blockHeight = 4

            for y = 7, height do
                table.insert(tiles[y],
                    Tile(x, y, tileID, y == 7 and topper or nil, tileset, topperset))
            end

            -- chance to generate a pillar
            if math.random(8) == 1 then
                blockHeight = 2
                
                -- chance to generate bush on pillar
                if math.random(8) == 1 then
                    table.insert(objects,
                        GameObject {
                            texture = 'bushes',
                            x = (x - 1) * TILE_SIZE,
                            y = (4 - 1) * TILE_SIZE,
                            width = 16,
                            height = 16,
                            
                            -- select random frame from bush_ids whitelist, then random row for variance
                            frame = BUSH_IDS[math.random(#BUSH_IDS)] + (math.random(4) - 1) * 7,
                            collidable = false
                        }
                    )
                end
                
                -- pillar tiles
                tiles[5][x] = Tile(x, 5, tileID, topper, tileset, topperset)
                tiles[6][x] = Tile(x, 6, tileID, nil, tileset, topperset)
                tiles[7][x].topper = nil
            
            -- chance to generate bushes
            elseif math.random(8) == 1 then
                table.insert(objects,
                    GameObject {
                        texture = 'bushes',
                        x = (x - 1) * TILE_SIZE,
                        y = (6 - 1) * TILE_SIZE,
                        width = 16,
                        height = 16,
                        frame = BUSH_IDS[math.random(#BUSH_IDS)] + (math.random(4) - 1) * 7,
                        collidable = false
                    }
                )
            end

            -- chance to spawn a block
            if math.random(10) == 1 then
                table.insert(objects,

                    -- jump block
                    GameObject {
                        texture = 'jump-blocks',
                        x = (x - 1) * TILE_SIZE,
                        y = (blockHeight - 1) * TILE_SIZE,
                        width = 16,
                        height = 16,

                        -- make it a random variant
                        frame = math.random(#JUMP_BLOCKS),
                        collidable = true,
                        hit = false,
                        solid = true,

                        -- collision function takes itself
                        onCollide = function(obj)

                            -- spawn a gem if we haven't already hit the block
                            if not obj.hit then

                                -- chance to spawn gem, not guaranteed
                                if math.random(5) == 1 then

                                    -- maintain reference so we can set it to nil
                                    local gem = GameObject {
                                        texture = 'gems',
                                        x = (x - 1) * TILE_SIZE,
                                        y = (blockHeight - 1) * TILE_SIZE - 4,
                                        width = 16,
                                        height = 16,
                                        frame = math.random(#GEMS),
                                        collidable = true,
                                        consumable = true,
                                        solid = false,

                                        -- gem has its own function to add to the player's score
                                        onConsume = function(player, object)
                                            gSounds['pickup']:play()
                                            player.score = player.score + 100
                                        end
                                    }
                                    
                                    -- make the gem move up from the block and play a sound
                                    Timer.tween(0.1, {
                                        [gem] = {y = (blockHeight - 2) * TILE_SIZE}
                                    })
                                    gSounds['powerup-reveal']:play()

                                    table.insert(objects, gem)
                                end

                                obj.hit = true
                            end

                            gSounds['empty-block']:play()
                        end
                    }
                )
            end
        end
    end

    local map = TileMap(width, height)
    map.tiles = tiles
    
    return GameLevel(entities, objects, map)
end

function get_Flag(tiles, objects, width, height, flagpost_color)

    local flag = {}
    local y_Pos = 6
    local x_Pos = -1

    -- check valid flag position
    for x = width - 1, 1, -1 do
        if tiles[y_Pos][x].id == TILE_ID_EMPTY and tiles[y_Pos + 1][x].id == TILE_ID_GROUND then
            x_Pos = x
            break
        end
    end

    for k, obj in pairs(objects) do 
        if obj.x == (x_Pos - 1) * TILE_SIZE then
            table.remove(objects, k)
        end 
    end
    
    -- flagpost creation
    for pole_Part = 2, 0, -1 do
        
        table.insert(flag, generate_FlagPost(width, flagpost_color, x_Pos, y_Pos, pole_Part))

        if pole_Part == 1 then

            y_Pos = y_Pos - 1
            table.insert(flag, generate_FlagPost(width, flagpost_color, x_Pos, y_Pos, pole_Part))

            y_Pos = y_Pos - 1
            table.insert(flag, generate_FlagPost(width, flagpost_color, x_Pos, y_Pos, pole_Part))
        end

        y_Pos = y_Pos - 1
    end

    -- add flag
    table.insert(flag, generate_Flag(width, x_Pos, y_Pos + 2))

    return flag
end

function generate_Flag(width, x_Pos, y_Pos)

    local base_Frame = FLAGS[math.random(#FLAGS)]

    return GameObject {
        texture = 'flags'

        x, y = (x_Pos - 1) * TILE_SIZE + 8, (y_Pos - 1) * TILE_SIZE - 8,  -- offset for better looks

        width, height = 16, 16,

        animation = Animation {
            frames = {base_Frame, base_Frame + 1},
            intervals = 0.2
        }
    }
end

function generate_FlagPost(width, flagpost_color, x_Pos, y_Pos, pole_Part)

    return GameObject {
        texture = 'flags'

        x, y = (x_Pos - 1) * TILE_SIZE, (y_Pos - 1) * TILE_SIZE,  -- offset for better looks

        width, height = 6, 16,

        frame = flagpost_color + pole_Part * FLAG_OFFSET,

        collidable, consumable, solid = true, true, false,

        onConsume = function(player, object)
            gSounds['pickup']:play()
            player.score = player.score + 250 *  get_FLag_SegmentMultiplier(pole_Part)

            gStateMachine:change ('play', {
                level_Width =  width + 10,
                score = player.score,
                level_Complete = true
            })

        end
    }
end

function get_FLag_SegmentMultiplier(pole_Part)

    if pole_Part == 0 then
        return 3
    elseif pole_Part == 1 then
        return 2
    elseif pole_Part == 2 then
        return 1
    end

    return 0
end
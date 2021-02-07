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
    local ground_Height = 6
    local pillar_Height = 4
    
    -- whether we should draw our tiles with toppers
    local topper = true
    local tileset = math.random(20)
    local topperset = math.random(20)

    -- MARIO UPDATE
    local KeyLock_Color = math.random(#KEYS_LOCKS)
    local flagpost_Color = math.random(#FLAGS)

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

        ::continue::
    end

    -- MARIO UPDATE: Lock block generation
    local spawned = false
    while not spawned do
        local x_Pos = math.random(width)
        if tiles[height][x_Pos].id == TILE_ID_GROUND then

            local block_Height
            if tiles[ground_Height][x_Pos].id == TILE_ then
                block_Height = ground_Height - 2
            elseif tiles[pillar_Height][x_Pos].id == TILE_ID_EMPTY then
                block_Height = pillar_Height - 2
            end

            local lock = get_KeyLock_Base(LOCK_ID, block_Height, x_Pos, KeyLock_Color)

            -- if player has key, the block is marked as "remove" and the key is removed too.
            lock.onCollide = function(player, object)

                if player.key_Obj then
                    gSounds['pickup']:play()
                    player.key_Obj = nil
                    player.remove = true

                    -- flag generation
                    local flag_Objects = get_Flag(tiles, objects, width, height, flagpost_Color)
                    for k, obj in pairs(flag_Objects) do
                        table.insert(objects, obj)
                    end
                else
                    gSounds['empty-block']:play()
                end
            end
            table.insert(objects, GameObject(lock))
            spawned = true

            -- remove any block at the key block position
            for k, obj in pairs(objects) do

                if obj.texture == 'jump-blocks' and obj.x  == (x_Pos - 1) * TILE_SIZE then
                    table.remove(objects, k)
                    break
                end
            end
        end
    end

    -- key generation
    spawned = false
    while not spawned do -- try to find a position where to spawn the key
        local x_Pos = math.random(width)
        if tiles[height][x_Pos].id == TILE_ID_GROUND then -- check if the tile is a ground and not a chasm

            local  block_Height -- check whether there's a pillar or a ground
            if tiles[ground_Height][x_Pos].id == TILE_ID_EMPTY then
                block_Height = ground_Height - 2
            elseif tiles[pillar_Height][x_Pos].id == TILE_ID_EMPTY then
                block_Height = pillar_Height - 2
            end

            local key = get_KeyLock_Base(KEY_ID, block_Height, x_Pos, KeyLock_Color)

            -- if player has key, the block is marked as "remove" and the key is removed too.
            key.onConsume = function(player, object)
                gSounds['pickup']:play()
                player.key_Obj = object
            end
            table.insert(objects, GameObject(lock))
            spawned = true
        end
    end

    local map = TileMap(width, height)
    map.tiles = tiles
    
    return GameLevel(entities, objects, map)
end

function get_KeyLock_Base(Key_or_Lock, block_Height, x, KeyLock_Color)

    -- The y position  for a key is the ground and for a block the block height
    local y_Pos = Key_or_Lock == KEY_ID and block_Height + 2 or block_Height

    return{
        texture = 'keys_locks',
        x = (x_Pos - 1) * TILE_SIZE,
        y = (y_Pos - 1) * TILE_SIZE,  -- offset for better looks
        width = 16,
        height = 16,
        collidable = true,
        consumable = Key_or_Lock == KEY_ID,
        solid = Key_or_Lock == LOCK_ID,
        frame = KEYS_LOCKS[KeyLock_Color] + Key_or_Lock
    }
end

function get_Flag(tiles, objects, width, height, flagpost_Color)

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
    
    -- MARIO UPDATE: flagpost creation
    for pole_Part = 2, 0, -1 do
        
        table.insert(flag, generate_FlagPost(width, flagpost_Color, x_Pos, y_Pos, pole_Part))

        if pole_Part == 1 then

            y_Pos = y_Pos - 1
            table.insert(flag, generate_FlagPost(width, flagpost_Color, x_Pos, y_Pos, pole_Part))

            y_Pos = y_Pos - 1
            table.insert(flag, generate_FlagPost(width, flagpost_Color, x_Pos, y_Pos, pole_Part))
        end

        y_Pos = y_Pos - 1
    end

    -- MARIO UPDATE: add flag
    table.insert(flag, generate_Flag(width, x_Pos, y_Pos + 2))

    return flag
end

function generate_Flag(width, x_Pos, y_Pos)

    local base_Frame = FLAGS[math.random(#FLAGS)]

    return GameObject {
        texture = 'flags',

        x = (x_Pos - 1) * TILE_SIZE + 8,
        y = (y_Pos - 1) * TILE_SIZE - 8,  -- offset for better looks

        width = 16,
        height = 16,

        animation = Animation {
            frames = {base_Frame, base_Frame + 1},
            intervals = 0.2
        }
    }
end

function generate_FlagPost(width, flagpost_Color, x_Pos, y_Pos, pole_Part)

    return GameObject {
        texture = 'flags',
        x = (x_Pos - 1) * TILE_SIZE,
        y = (y_Pos - 1) * TILE_SIZE,  
        width = 6,
        height = 16, 
        frame = flagpost_Color + pole_Part * FLAG_OFFSET,
        collidable = true, 
        consumable = true,
        solid = false,

        -- MARIO UPDATE: When the flag/flagpost is touched, a new level starts
        onConsume = function(player, object)
            gSounds['pickup']:play()
            player.score = player.score + 250 * get_FLag_SegmentMultiplier(pole_Part)

            gStateMachine:change ('play',{
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
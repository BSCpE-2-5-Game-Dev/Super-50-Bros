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

    local groundHeight = 6
    local pillarHeight = 4
    
    -- whether we should draw our tiles with toppers
    local topper = true
    local tileset = math.random(20)
    local topperset = math.random(20)

    -- MARIO UPDATE
    local keyLockColor = math.random(#KEYS_LOCKS)
    local flagPostColor = math.random(#FLAG_POSTS)

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

        -- MARIO UPDATE: Generate ground for the first three tiles
        if x <= 3 then
            tileID = TILE_ID_GROUND
            for y = 7, height do
                table.insert(tiles[y],
                    Tile(x, y, tileID, y == 7 and topper or nil, tileset, topperset))
            end
            goto continue
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
            local blockHeight = groundHeight - 2

            for y = 7, height do
                table.insert(tiles[y],
                    Tile(x, y, tileID, y == 7 and topper or nil, tileset, topperset))
            end

            -- chance to generate a pillar
            if math.random(8) == 1 then
                blockHeight = pillarHeight - 2
                
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
        local xPos = math.random(width)
        if tiles[height][xPos].id == TILE_ID_GROUND then

            local blockHeight
            if tiles[groundHeight][xPos].id == TILE_ID_EMPTY then
                blockHeight = groundHeight - 2
            elseif tiles[pillarHeight][xPos].id == TILE_ID_EMPTY then
                blockHeight = pillarHeight - 2
            end

            local lock = getKeyLockBase(LOCK_ID, blockHeight, xPos, keyLockColor)

            -- if player has key, the block is marked as "remove" and the key is removed too.
            lock.onCollide = function(player, object)

                if player.keyObj then
                    gSounds['pickup']:play()
                    player.keyObj = nil
                    object.remove = true

                    -- flag generation
                    local flagObjects = getFlag(tiles, objects, width, height, flagPostColor)
                    for k, obj in pairs(flagObjects) do
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
                if obj.texture == 'jump-blocks' and obj.x  == (xPos - 1) * TILE_SIZE then
                    table.remove(objects, k)
                    break
                end
            end
        end
    end

    -- key generation
    spawned = false
    while not spawned do -- try to find a position where to spawn the key
        local xPos = math.random(width)
        if tiles[height][xPos].id == TILE_ID_GROUND then -- check if the tile is a ground and not a chasm
            local  blockHeight -- check whether there's a pillar or a ground
            if tiles[groundHeight][xPos].id == TILE_ID_EMPTY then
                blockHeight = groundHeight - 2
            elseif tiles[pillarHeight][xPos].id == TILE_ID_EMPTY then
                blockHeight = pillarHeight - 2
            end

            local key = getKeyLockBase(KEY_ID, blockHeight, xPos, keyLockColor)

            -- if player has key, the block is marked as "remove" and the key is removed too.
            key.onConsume = function(player, object)
                gSounds['pickup']:play()
                player.keyObj = object
            end
            table.insert(objects, GameObject(key))
            spawned = true
        end
    end

    local map = TileMap(width, height)
    map.tiles = tiles
    
    return GameLevel(entities, objects, map)
end

-- MARIO UPDATE:
function getKeyLockBase(keyOrLock, blockHeight, x, keyLockColor)

    -- The y position  for a key is the ground and for a block the block height
    local yPos = keyOrLock == KEY_ID and blockHeight + 2 or blockHeight
    return {
        texture = 'keys-locks',
        x = (x - 1) * TILE_SIZE,
        y = (yPos - 1) * TILE_SIZE,  
        width = 16,
        height = 16,

        collidable = true,
        consumable = keyOrLock == KEY_ID,  -- a key is consumable, a lock not
        solid = keyOrLock == LOCK_ID,      -- a lock is solid, a key not

        frame = KEYS_LOCKS[keyLockColor] + keyOrLock
    }
end

function getFlag(tiles, objects, width, height, flagPostColor)

    local flag = {}
    local yPos = 6
    local xPos = -1

    -- check valid flag position
    for x = width - 1, 1, -1 do
        if tiles[yPos][x].id == TILE_ID_EMPTY and tiles[yPos + 1][x].id == TILE_ID_GROUND then
            xPos = x
            break
        end
    end

    for k, obj in pairs(objects) do 
        if obj.x == (xPos - 1) * TILE_SIZE then
            table.remove(objects, k)
        end 
    end
    
    -- MARIO UPDATE: flagpost creation
    for poleType = 2, 0, -1 do
        
        table.insert(flag, generateFlagPost(width, flagPostColor, xPos, yPos, poleType))

        if poleType == 1 then
            yPos = yPos - 1
            table.insert(flag, generateFlagPost(width, flagPostColor, xPos, yPos, poleType))

            yPos = yPos - 1
            table.insert(flag, generateFlagPost(width, flagPostColor, xPos, yPos, poleType))
        end

        yPos = yPos - 1
    end

    -- MARIO UPDATE: add flag
    table.insert(flag, generateFlag(width, xPos, yPos + 2))

    return flag
end

function generateFlag(width, xPos, yPos)
    local base_Frame = FLAGS[math.random(#FLAGS)]
    return GameObject {
        texture = 'flags',
        x = (xPos - 1) * TILE_SIZE + 8,
        y = (yPos - 1) * TILE_SIZE - 8,  -- offset for better looks
        width = 16,
        height = 16,
        animation = Animation {
            frames = {base_Frame, base_Frame + 1},
            intervals = 0.2
        }
    }
end

function generateFlagPost(width, flagPostColor, xPos, yPos, poleType)
    return GameObject {
        texture = 'flags',
        x = (xPos - 1) * TILE_SIZE,
        y = (yPos - 1) * TILE_SIZE,  
        width = 6,
        height = 16, 
        frame = flagPostColor + poleType * FLAG_OFFSET,
        collidable = true, 
        consumable = true,
        solid = false,

        -- MARIO UPDATE: When the flag/flagpost is touched, a new level starts
        onConsume = function(player, object)
            gSounds['pickup']:play()
            player.score = player.score + 250 * getFlagSegmentMultiplier(poleType)

            gStateMachine:change ('play',{
                levelWidth =  width + 10,  -- increment the level width
                score = player.score,
                levelComplete = true
            })
        end
    }
end

function getFlagSegmentMultiplier(poleType)
    if poleType == 0 then
        return 3
    elseif poleType == 1 then
        return 2
    elseif poleType == 2 then
        return 1
    end

    return 0
end
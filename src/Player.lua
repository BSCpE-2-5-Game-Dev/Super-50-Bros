--[[
    GD50
    Super Mario Bros. Remake

    -- Player Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu
]]

Player = Class{__includes = Entity}

function Player:init(def)
    Entity.init(self, def)
    -- MARIO UPDATE
    self.score = def.score or 0
    self.key_Obj = nil
    self.level_Complete = def.level_Complete

    if self.level_Complete then
        Timer.after(4, function () self.level_Complete = false end)
    end
end

function Player:update(dt)
    Entity.update(self, dt)
end

function Player:render()
    Entity.render(self)
end

function player:renderLevel_Complete()
    love.graphics.setFont(gFonts['medium'])
    lvoe.graphics.setColor(0, 0, 0, 255)
    love.graphics.printf("Level Complete!", 0, 5, VIRTUAL_WIDTH, 'center')
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.printf("Level Complete!", 0, 4, VIRTUAL_WIDTH - 1, 'center')


function Player:checkLeftCollisions(dt)
    -- check for left two tiles collision
    local tileTopLeft = self.map:pointToTile(self.x + 1, self.y + 1)
    local tileBottomLeft = self.map:pointToTile(self.x + 1, self.y + self.height - 1)

    -- place player outside the X bounds on one of the tiles to reset any overlap
    if (tileTopLeft and tileBottomLeft) and (tileTopLeft:collidable() or tileBottomLeft:collidable()) then
        self.x = (tileTopLeft.x - 1) * TILE_SIZE + tileTopLeft.width - 1
    else
        
        -- allow us to walk atop solid objects even if we collide with them
        self.y = self.y - 1
        local collidedObjects = self:checkObjectCollisions()
        self.y = self.y + 1

        -- reset X if new collided object
        if #collidedObjects > 0 then
            self.x = self.x + PLAYER_WALK_SPEED * dt
        end
    end
end

function Player:checkRightCollisions(dt)
    -- check for right two tiles collision
    local tileTopRight = self.map:pointToTile(self.x + self.width - 1, self.y + 1)
    local tileBottomRight = self.map:pointToTile(self.x + self.width - 1, self.y + self.height - 1)

    -- place player outside the X bounds on one of the tiles to reset any overlap
    if (tileTopRight and tileBottomRight) and (tileTopRight:collidable() or tileBottomRight:collidable()) then
        self.x = (tileTopRight.x - 1) * TILE_SIZE - self.width
    else
        
        -- allow us to walk atop solid objects even if we collide with them
        self.y = self.y - 1
        local collidedObjects = self:checkObjectCollisions()
        self.y = self.y + 1

        -- reset X if new collided object
        if #collidedObjects > 0 then
            self.x = self.x - PLAYER_WALK_SPEED * dt
        end
    end
end

function Player:checkObjectCollisions()
    local collidedObjects = {}

    for k, object in pairs(self.level.objects) do
        if object:collides(self) then
            if object.solid then
                table.insert(collidedObjects, object)
            elseif object.consumable then
                object.onConsume(self, object)
                table.remove(self.level.objects, k)
            end
        end
    end

    return collidedObjects
end
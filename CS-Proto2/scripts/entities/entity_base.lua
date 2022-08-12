Object = require "libs.classic.classic"

Entity = Object:extend()

-- handles entity and tile collision, movement
function Entity:new(x, y, collision_world, tile_world)
  self.pos = vector(x, y)
  -- variable represeting the position of the object on the ground, regardless of the height they are drawn at
  self.ground_pos = self.pos
  -- variable added to the y-position, representing the height of the object
  self.height = 0
  self.collision_world = collision_world
  self.tile_world = tile_world
  -- Entities should only have one tile collider
  self.tile_collider = nil
  self.colliders = {}
  self.do_collision = true
  -- Entities will have to intialize their move and anim components themselves
  self.Move = nil
  self.Anim = nil
  self.base_image_offset = vector(0, 0)
  self.collision_resolution = {}
  self.collision_condition = {}
end

function Entity:update(dt)
  self:updateMovement(dt, self.Move:getMovementStep(dt))
end

function Entity:updateMovement(dt, movementStep)
  --local last_pos = self.ground_pos
  local target_pos = self.ground_pos + movementStep
  
  -- moving taking the tile collider into account
  if(self.Move and self.tile_collider and self.do_collision) then
    local move_step = movementStep
    local goal_pos = (self.ground_pos + move_step) - self.tile_collider_offset
    local actualX, actualY, cols, len = self.tile_world:move(self, goal_pos.x, goal_pos.y, function(item, other) return self:checkTileCollisionForHeight(item, other) end)
    self.ground_pos = vector(actualX, actualY) + self.tile_collider_offset
    -- updates the variable that indicates whether an entity is running into a wall horizontally or not
    --if actualX - goal_pos.x ~= 0 then self.moving_into_wall_x = true else self.moving_into_wall_x = false end 
    self.pos = self.ground_pos - vector(0, self.height)
    -- rounding position values makes you get stuck on colliders :/
    --self.pos = vector(math.floor(self.pos.x), math.floor(self.pos.y))
  -- moving without a tile collider
  elseif(self.Move) then
    self.ground_pos = self.ground_pos + movementStep
    self.pos = self.ground_pos - vector(0, self.height)
  end
  
  self:updateColliderPositions()
  self:resolveCollisions()
  self:updateColliderPositions()
  
  --if self.ground_pos.x ~= target_pos.x then self.moving_into_wall_x = true else self.moving_into_wall_x = false end 
  --print(self.moving_into_wall_x)
end

-- @param new_pos: a vector representing the new position of the entity
function Entity:moveTo(new_pos)
  self.ground_pos = new_pos
  self.pos = self.ground_pos - vector(0, self.height)
  self.position = self.pos
end 
  
function Entity:setUpTileCollider(x, y, ox, oy, w, h)
  self.tile_collider = self.tile_world:add(self, x - ox, y - oy, w, h) 
  self.tile_collider_offset = vector(ox, oy)
end

-- function used to resolve tile collisions based on what the function returns
--function Entity:resolveTileCollisions(item, other)

function Entity:checkTileCollisionForHeight(item, other)
  -- disables tile collisions between entities (for now)
  if(not other.isTile and self:is(Entity)) then return false end
  
  -- allows entities to skip over tiles if they are above a certain height
  if(self.height > 50) then
    return false
  else
    return 'slide'
  end
end

-- @param collider: collider object to add
-- @param tag: string that identifies what the collider represents; collisions are resolved based on this
-- @param position_function: function that returns a vector, to decide where the position of the collider is
-- @param (optional) enabled: boolean: collisions are resolved only if this is true. it is true by default.
function Entity:addCollider(collider, tag, object, position_function, enabled)
  collider.tag = tag
  collider.object = object
  collider.position_function = position_function 
  collider:moveTo(position_function())
  if enabled == nil then collider.enabled = true else collider.enabled = enabled end
  table.insert(self.colliders, collider)
  return collider
end

-- @param native_collider: string: tag of a collider belonging to the entity calling the method
-- @param foreign_collider: string: tag of a collider belonging to any other entity
-- @param response: function that runs whenever the native and foreign colliders collide.
function Entity:setCollisionResolution(native_collider, foreign_collider, response)
  if not self.collision_resolution[native_collider] then self.collision_resolution[native_collider] = {} end
  self.collision_resolution[native_collider][foreign_collider] = response
end

-- @param native_collider: string: tag of a collider belonging to the entity calling the method
-- @param foreign_collider: string: tag of a collider belonging to any other entity
-- @param condition: function that returns a boolean, true meaning the colliders can collide and false meaning they can't.
function Entity:setCollisionCondition(native_collider, foreign_collider, condition)
  if not self.collision_condition[native_collider] then self.collision_condition[native_collider] = {} end
  self.collision_condition[native_collider][foreign_collider] = condition
end

function Entity:updateColliderPositions()
  for _,c in ipairs(self.colliders) do
    c:moveTo(c.position_function())
  end
end

-- this birds gotta big nest (lol!)
function Entity:resolveCollisions()
  if not self.do_collision then return false end
  for _,c in ipairs(self.colliders) do
    if self.collision_resolution[c.tag] and c.enabled then
      local collisions = self.collision_world:collisions(c)
      for other, separating_vector in pairs(collisions) do
        if other.object.do_collision and other.enabled and self.collision_resolution[c.tag][other.tag] then 
          -- this checks the collision_condition table for each entity in the collision. If either condition returns false, than this collision is ignored and neither entity responds
          local condition_check = (self.collision_condition[c.tag] and self.collision_condition[c.tag][other.tag] and not(self.collision_condition[c.tag][other.tag]())) or (other.object.collision_condition[other.tag] and other.object.collision_condition[other.tag][c.tag] and not(other.object.collision_condition[other.tag][c.tag]()))
          if not condition_check then self.collision_resolution[c.tag][other.tag](separating_vector, other) end
        end
      end
    end
  end
end

-- method that check for collision with scenery objects with an entity collider
function Entity:checkEntityCollision(collider, test_pos)
  collider:moveTo(test_pos.x, test_pos.y)
  local collisions = self.collision_world:collisions(collider)
  for other, separating_vector in pairs(collisions) do
    if other.tag == "Test" then collider:moveTo(collider.position_function()) return true end
  end
  collider:moveTo(collider.position_function())
  return false
end

-- method that checks for collision with the tile colliders belonging to the tile map
function Entity:checkTileCollision(test_pos)
  local goal_pos = test_pos - self.tile_collider_offset
  local actualX, actualY, cols, len = self.tile_world:check(self, goal_pos.x, goal_pos.y, function(item, other) return self:checkTileCollisionForHeight(item, other) end)
  return actualX ~= goal_pos.x or actualY ~= goal_pos.y
end
  

function Entity:drawColliders()
  if not self.do_collision then return false end
  for _,c in ipairs(self.colliders) do
    if c.enabled then c:draw() end
  end
end

function Entity:drawTileCollider()
  love.graphics.setColor(0.54,0.81,0.94)
  local tcx, tcy, tcw, tch = self.tile_world:getRect(self)
  love.graphics.rectangle("line", tcx, tcy, tcw, tch)
  love.graphics.setColor(1, 1, 1, 1) 
end

function Entity:drawRenderPosition()
  love.graphics.setColor(0.91,0.45,0.31)
  love.graphics.line(self.pos.x - 30, self:getRenderPosition(), self.pos.x + 30, self:getRenderPosition())
  love.graphics.setColor(1, 1, 1, 1) 
end

function Entity:removeCollider(collider_object)
  for i,v in ipairs(self.colliders) do
    if v == collider_object then self.collision_world:remove(collider_object) table.remove(self.colliders, i) end
  end
end
  
function Entity:getRenderPosition() 
  local oy = self.base_image_offset.y
  return math.floor(((self.pos.y + self.height) + oy) + 0.5)
end

return Entity
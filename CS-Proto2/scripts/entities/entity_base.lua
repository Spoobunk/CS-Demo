Object = require "libs.classic.classic"

Entity = Object:extend()

-- handles entity and tile collision, movement
function Entity:new(x, y, base_height, collision_world, tile_world)
    -- variable represeting the position of the object when on the ground, regardless of the height they are drawn at
  self.ground_pos = vector(x, y)
  -- variable representing the 'height' of the object on the ground, in other words, the distance between the position of the object on the imagined ground, and the actual position of the object on the 2D world of the game
  self.base_height = base_height
  self.pos = self.ground_pos + vector(0, self.base_height)
  -- variable added to the y-position, representing the height of the object
  self.height = 0
  self.collision_world = collision_world
  self.tile_world = tile_world
  self.current_movestep = vector(0, 0)
  -- Entities should only have one tile collider
  self.tile_collider = nil
  self.colliders = {}
  self.do_collision = true
  -- Entities will have to intialize their move and anim components themselves
  self.Move = nil
  self.Anim = nil
  self.collision_resolution = {}
  self.collision_condition = {}
end

function Entity:update(dt)
  self:updateMovement(dt, self.Move:getMovementStep(dt))
end

function Entity:updateMovement(dt, movementStep)
  local last_pos = self.ground_pos
  local target_pos = self.ground_pos + movementStep
  
  -- moving taking the tile collider into account
  if(self.Move and self.tile_collider) then
    local move_step = movementStep
    local goal_pos = (self.ground_pos + move_step) - self.tile_collider_offset
    if self.do_collision then
      -- move the collider with collision detection
      local actualX, actualY, cols, len = self.tile_world:move(self, goal_pos.x, goal_pos.y, function(item, other) return self:checkTileCollisions(item, other) end)
      self.ground_pos = vector(actualX, actualY) + self.tile_collider_offset
      self.pos = self.ground_pos - vector(0, self.base_height + self.height)
      self:resolveTileCollisions(cols)
    else
      -- move the tile collider without collision detection
      self.tile_world:update(self, goal_pos.x, goal_pos.y)
      self.ground_pos = goal_pos + self.tile_collider_offset
      self.pos = self.ground_pos - vector(0, self.base_height + self.height)
    end
    
  -- moving without a tile collider
  elseif(self.Move) then
    self.ground_pos = self.ground_pos + movementStep
    self.pos = self.ground_pos - vector(0, self.base_height + self.height)
  end
  
  self:updateColliderPositions()
  self:resolveCollisions()
  self:updateColliderPositions()
  
  self.current_movestep = self.ground_pos - last_pos
end

-- @param {vector} new_pos The new position of the entity
function Entity:moveTo(new_pos)
  if not vector.isvector(new_pos) then error('the new position provided to the moveTo function must be a vector') end
  
  self.ground_pos = new_pos
  self.pos = self.ground_pos - vector(0, self.base_height + self.height)
  
  if self.tile_collider then
    local new_tile_pos = new_pos:clone() - self.tile_collider_offset
    if self.do_collision then
      -- updating the tile collider position with collision
      local actualX, actualY, cols, len = self.tile_world:move(self, new_tile_pos.x, new_tile_pos.y, function(item, other) return self:checkTileCollisions(item, other) end)
      self.ground_pos = vector(actualX, actualY) + self.tile_collider_offset
      self.pos = self.ground_pos - vector(0, self.base_height + self.height)
      self:resolveTileCollisions(cols)
    else
      -- updating the tile collider position without collision
      self.tile_world:update(self, new_tile_pos.x, new_tile_pos.y)
    end
  end
end
  
-- intializes the tile collider, which is oriented with ground_pos + vector(0, base_height) as the origin
-- @param {number} ox The distance between the entity's ground_pos and the left side of the collider
-- @param {number} oy The distance between the entity's ground_pos and the top of the collider
-- @param {number} w The width of the collider, the distance from the collider's left side to the right side
-- @param {number} h The height of the collider, the distance from the top to the bottom
function Entity:setUpTileCollider(ox, oy, w, h)
  self.tile_collider = self.tile_world:add(self, self.ground_pos.x - ox, self.ground_pos.y - (self.base_height + oy), w, h) 
  self.tile_collider_offset = vector(ox, self.base_height + oy)
end

-- function used to check tile collisions and use preliminary collision resolution options 'slide, bounce'
-- more advanced collision resolution comes later
function Entity:checkTileCollisions(item, other)
  return self:checkTileCollisionForHeight(item, other)
end

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

-- function that is called right after tile collisions are evaluated, overidden by Grabbable base class
function Entity:resolveTileCollisions(cols)
end

-- @param collider: collider object to add
-- @param tag: string that identifies what the collider represents; collisions are resolved based on this
-- @param position_function: function that returns a set of two numbers (not a vector), to decide where the position of the collider is
-- @param (optional) enabled: boolean: collisions are resolved only if this is true. it is true by default.
-- @param (optional) ignore_height: boolean, whether the collider checks that it is not too high when resolving collisions
function Entity:addCollider(collider, tag, object, position_function, enabled, ignore_height)
  collider.tag = tag
  collider.object = object
  collider.position_function = position_function 
  -- the position function must return a set of two numbers, NOT a vector...
  collider:moveTo(position_function())
  if enabled == nil then collider.enabled = true else collider.enabled = enabled end
  -- if ignore_height isn't supplied, it will be nil
  collider.ignore_height = ignore_height
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
      if c.ignore_height or self.height < 50 then
        local collisions = self.collision_world:collisions(c)
        for other, separating_vector in pairs(collisions) do
          if other.object.do_collision and other.enabled and self.collision_resolution[c.tag][other.tag] then
            if other.ignore_height or other.object.height < 50 then
              -- this checks the collision_condition table for each entity in the collision. If either condition returns false, than this collision is ignored and neither entity responds
              local condition_check = (self.collision_condition[c.tag] and self.collision_condition[c.tag][other.tag] and not(self.collision_condition[c.tag][other.tag]())) or (other.object.collision_condition[other.tag] and other.object.collision_condition[other.tag][c.tag] and not(other.object.collision_condition[other.tag][c.tag]()))
              if not condition_check then self.collision_resolution[c.tag][other.tag](separating_vector, other, c) end
            end
          end
        end
      end
    end
  end
end

-- method that check for collision with scenery objects with an entity collider
-- @param {collider} collider The collider to test
-- @param {vector} test_pos The position to test the collider at
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
-- @param {vector} test_pos The ground position you want to test at (tile colliders are always placed relative to the ground position of the enemy they are attached to)
function Entity:checkTileCollision(test_pos)
  local goal_pos = test_pos - self.tile_collider_offset
  local actualX, actualY, cols, len = self.tile_world:check(self, goal_pos.x, goal_pos.y, function(item, other) return self:checkTileCollisionForHeight(item, other) end)
  return actualX ~= goal_pos.x or actualY ~= goal_pos.y
end

-- a function to be used as a collision response between two entities. It pushes first entity away from the second smoothly, with the push back being proportional to the distance between them
-- @param {table} separating_vector A table with x and y values representing the distance the native collider needs to move to clear the collision
-- @param {collider} other The foreign collider that the native collider collided with
-- @param {number} max_push (optional) A number representing the maximum push back that can be delivered, subtracted by the min_push value (usually a number between 0 and 1) 0.5 by default
-- @param {number} min_push (optional) A number representing the minimum push back that can be delivered (usually a number between 0 and 1) 0.05 by default
function Entity:entityCollisionPushBack(separating_vector, other, max_push, min_push)
  -- the other collider is checked to make sure it is attached to an entity with access to the moveTo() method
  if not other.object:is(Entity) then error("You can't use the entityCollisionPushBack method as a collision response to a collider that isn't attached to an entity. The collider tagged " .. other.tag .. " is not attached to an entity.") end
  local sv = vector(separating_vector.x, separating_vector.y)
  -- the radius of a circle that fully encloses the other collider. If the other collider is already a circle, than it is just the radius of the collider.
  local _, _, c_radius = other:outcircle()
  -- this makes it so the magnitude of the push back is proportional to how close the our collider is to the center for the other collider, resulting in a harsh pushback that becomes more gentle the farther our collider is from the center
  local distance_from_center = math.min(sv:len() / c_radius, 1) * (max_push or 0.5) + (min_push or 0.05)
  local push_back = sv * distance_from_center
  -- alternative push back calculation that uses c_radius instead of the length of the separating vector
  --local push_back = sv:normalizeInplace() * (c_radius * distance_from_center)
  self:moveTo(self.ground_pos + push_back) 
end
  
-- draws all colliders attached to this entity
function Entity:drawColliders()
  --if not self.do_collision then return false end
  for _,c in ipairs(self.colliders) do
    if c.enabled and (c.ignore_height or self.height < 50) then c:draw() end
  end
end

-- draws a circle that fully encloses the collider's shape for each collider attached to this entity
function Entity:drawColliderOutCircle()
  --if not self.do_collision then return false end
  for _,c in ipairs(self.colliders) do
    if c.enabled and (c.ignore_height or self.height < 50) then love.graphics.circle('line', c:outcircle()) end
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
  --local oy = self.base_image_offset.y
  --return math.floor(((self.pos.y + self.height) + oy) + 0.5)
  return self.ground_pos.y
end

return Entity
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
  -- Entities will have to intialize their move and anim components themselves
  self.Move = nil
  self.Anim = nil
  self.base_image_offset = vector(0, 0)
end

function Entity:update(dt)
  -- moving taking the tile collider into account
  if(self.Move and self.tile_collider) then
    local move_step = self.Move:getMovementStep(dt)
    local goal_pos = (self.ground_pos + move_step) - self.tile_collider_offset
    local actualX, actualY, cols, len = self.tile_world:move(self, goal_pos.x, goal_pos.y, function() return self:checkTileCollisionForHeight() end)
    self.ground_pos = vector(actualX, actualY) + self.tile_collider_offset
    self.pos = self.ground_pos - vector(0, self.height)
  -- moving without a tile collider
  elseif(self.Move) then
    self.ground_pos = self.ground_pos + self.Move:getMovementStep(dt)
    self.pos = self.ground_pos - vector(0, self.height)
  end
  
  self:updateColliderPositions()
  self:resolveCollisions()
end

function Entity:setUpTileCollider(x, y, ox, oy, w, h)
  self.tile_collider = self.tile_world:add(self, x - ox, y - oy, w, h) 
  self.tile_collider_offset = vector(ox, oy)
end

function Entity:checkTileCollisionForHeight()
  -- allows entities to skip over tiles if they are above a certain height
  if(self.height > 50) then
    return false
  else
    return 'slide'
  end
end

function Entity:addCollider(collider, tag, object, position_function, enabled)
  collider.tag = tag
  collider.object = object
  collider.position_function = position_function 
  collider.enabled = enabled or false
  table.insert(self.colliders, collider)
  return collider
end

function Entity:updateColliderPositions()
  for _,c in ipairs(self.colliders) do
    c:moveTo(c.position_function())
  end
end

-- this birds gotta big nest (lol!)
function Entity:resolveCollisions()
  for _,c in ipairs(self.colliders) do
    if self.collision_resolution[c.tag] then
      local collisions = self.collision_world:collisions(c)
      for other, separating_vector in pairs(collisions) do
        if(self.collision_resolution[c.tag][other.tag]) then
          self.collision_resolution[c.tag][other.tag](separating_vector, other)
        end
      end
    end
  end
end

function Entity:drawColliders()
  for _,c in ipairs(self.colliders) do
    c:draw()
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
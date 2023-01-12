Grabbable = require "scripts.entities.entity_grabbable_base"

AnimComponent = require "scripts.entities.entity_anim_base"
MoveComponent = require "scripts.entities.entity_move_base"

OT = Grabbable:extend()

function OT:new(x, y, collision_world, tile_world)
  OT.super.new(self, x, y, 7, collision_world, tile_world, 'PushTest')
  self.name = 'object test'
  self.Move = MoveComponent(4, 0.09, 150)
  self.Anim = AnimComponent(self, love.graphics.newImage('assets/test/sprites/ball-test.png'))
  self.hitbox = self:addCollider(self.collision_world:circle(self.pos.x, self.pos.y, 15), "PushTest", self, function() return self.ground_pos.x, self.ground_pos.y - self.base_height end) 
  self:setUpTileCollider(7, 7, 14, 14)
  self.shadow_object = ShadowObject(self, 9, 7)
  self:setCollisionResolution('PushTest', 'Player', function(separating_vector, other) 
    self:entityCollisionPushBack(separating_vector, other, 0.1)
  end)
end

function Grabbable:instanceThrownCollider()
  self.thrown_hitbox = self:addThrownCollider(self.collision_world:circle(self.pos.x, self.pos.y, 15), function() return self.ground_pos.x, self.ground_pos.y - self.base_height end, 10, 0.1)
end

function OT:update(dt)
  if not self.in_suspense then
    self.Anim:update(dt)
    self.Move:update(dt)
  end
  OT.super.update(self, dt)
end

function OT:draw()
  local draw_pos = self.pos:clone()
  if self.current_shudder then draw_pos = draw_pos + self.current_shudder:amplitude() end
  --if self.name ~= 'bouncy test enemy' then self.Anim:draw(draw_pos:unpack()) end
  self.Anim:draw(draw_pos:unpack())
  -- draw box around current frame
  --self.Anim:drawFrameBox(self.pos.x, self.pos.y)
  
  --love.graphics.rectangle('line', self.pos.x, self.pos.y, self.Anim:getCurrentAnim():getDimensions())
  
  love.graphics.setColor(1, 0, 0, 1)
  --self:drawColliders()
  --self:drawTileCollider()
  --self:drawRenderPosition()
  --love.graphics.setColor(0, 0.8, 1, 1)
  --love.graphics.points(self.pos:unpack())
  --love.graphics.circle('line', self.pos.x, self.pos.y, 5)
  love.graphics.points(self.ground_pos:unpack())
  --love.graphics.circle('line', self.ground_pos.x, self.ground_pos.y, 5)
  love.graphics.setColor(1, 1, 1, 1)
end

return OT
Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

Entity = require "scripts.entities.entity_base"

utilities = require 'scripts.utilities'

Grabbable = Entity:extend()

function Grabbable:new(x, y, collision_world, tile_world, main_hitbox) 
  Grabbable.super.new(self, x, y, collision_world, tile_world)
  self.main_hitbox = main_hitbox
  --self.collision_resolution[self.main_hitbox] = {PlayerGrab = function(_, other) getGrabbed(other) end}
  self:setCollisionResolution(main_hitbox, 'PlayerGrab', function(_, other) self:getGrabbed(other) end)
  self:setCollisionResolution('PlayerThrown', 'Reflect', function(separating_vector) self:bounceOff(vector(separating_vector.x, separating_vector.y)) end)
  self.grabbed = false
  self.thrown = false
  self.player = nil
end

function Grabbable:update()
  if self.grabbed then self:updateMovement(dt, self.player.current_movestep) else self:updateMovement(dt, self.Move:getMovementStep(dt)) end
  if self.thrown then 
    if self.Move.velocity <= vector(50, 50) then 
      self:finishThrow()
    end
  end
end

-- used to add a thrown-type collider to the entity's set of colliders; shouldn't be overidden
function Grabbable:addThrownCollider(collider, position_function, damage, knockback)
  local thrown = self:addCollider(collider, "PlayerThrown", self, position_function, true)
  thrown.damage = damage
  thrown.knockback = knockback
  return thrown
end

-- used to define how each specific entity's thrown collider should be instantiated; should be overidden
function Grabbable:instanceThrownCollider()
  self.thrown_hitbox = self:addThrownCollider(self.collision_world:circle(self.pos.x, self.pos.y, 40), function() return self.ground_pos:unpack() end, 30, 400)
end

function Grabbable:getGrabbed(grab_collider)
  local signal = grab_collider.signal
  self.do_collision = false
  self.grabbed = true
  self.player = grab_collider.object
  signal:emit('grab-success', self)
end

-- @param throw_dir digital representation of 8-way throw direction (a vector)
function Grabbable:getThrown(throw_dir)
  self.do_collision = true
  self:instanceThrownCollider()
  self.grabbed = false
  self.player = nil
  self.thrown = true
  self.height = 0
  throw_dir:normalizeInplace()
  self.Move:setMovementSettings(vector(0, 0), throw_dir * 2000, 50, 0.5, 2000)
end

function Grabbable:finishThrow()
  self.thrown = false
  for _,c in ipairs(self.colliders) do
    if c.tag == 'PlayerThrown' then self:removeCollider(c) end
  end
end  

function Grabbable:bounceOff(separating_vector)
  --local knockback_velocity = separating_vector:normalizeInplace() * (self.Move.velocity:len())
  local deflected_velocity = self.Move.velocity:mirrorOn(separating_vector:perpendicular()) * 0.75
  self:moveTo(self.ground_pos + separating_vector)
  self.Move:setMovementSettings(nil, deflected_velocity, nil, nil, nil)
end


return Grabbable
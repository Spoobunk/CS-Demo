Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"
Signal = require "libs.hump.signal"

Entity = require "scripts.entities.entity_base"
Active = require "scripts.entities.entity_active_base"

utilities = require 'scripts.utilities'

Grabbable = Active:extend()

function Grabbable:new(x, y, base_height, collision_world, tile_world, main_hitbox) 
  Grabbable.super.new(self, x, y, base_height, collision_world, tile_world)
  self.main_hitbox = main_hitbox
  --self.collision_resolution[self.main_hitbox] = {PlayerGrab = function(_, other) getGrabbed(other) end}
  self:setCollisionResolution(main_hitbox, 'PlayerGrab', function(separating_vector, other) if not self.thrown then self:getGrabbed(other, vector(separating_vector.x, separating_vector.y)) end end)
  self:setCollisionResolution('PlayerThrown', 'Reflect', function(separating_vector) self:bounceOffEnvironment(vector(separating_vector.x, separating_vector.y)) end)
  self.grabbed = false
  self.thrown = false
  self.player = nil
  
  self.THROWN_MAX_VEL = 1400
end

-- Enemy base class overrides this
function Grabbable:update(dt)
  if self.grabbed then self:updateMovement(dt, self.player.current_movestep) else self:updateMovement(dt, self.Move:getMovementStep(dt)) end
  if self.thrown then 
    self:updateRotationSpeed()
    if self.Move.velocity:len() <= 50 then 
      self:finishThrow()
    end
  end
  
  Grabbable.super.update(self, dt)
end

function Grabbable:checkTileCollisions(item, other)
  return self:checkTileCollisionForThrown(item, other)
end

function Grabbable:checkTileCollisionForThrown(item, other)
  if self:checkTileCollisionForHeight(item, other) == 'slide' then 
    if self.thrown then
      return 'bounce'
    else
      return 'slide'
    end
  else
    return self:checkTileCollisionForHeight(item, other)
  end
end

function Grabbable:resolveTileCollisions(cols)
  for i,col in ipairs(cols) do
    if col.type == 'bounce' then 
      self:bounceOffEnvironment(vector(col.normal.x, col.normal.y))
    end
  end
end

-- used to add a thrown-type collider to the entity's set of colliders; shouldn't be overidden
function Grabbable:addThrownCollider(collider, position_function, damage, suspense)
  local thrown = self:addCollider(collider, "PlayerThrown", self, position_function, true)
  thrown.damage = damage
  thrown.suspense = suspense
  thrown.signal = Signal.new()
  thrown.signal:register('hit-confirm', function(seperating_vector, own_collider) self:onHit(seperating_vector, own_collider) end)
  thrown.signal:register('dink-confirm', function(seperating_vector, own_collider) self:onDink(seperating_vector, own_collider) end)
  return thrown
end

-- used to define how each specific entity's thrown collider should be instantiated; should be overidden
function Grabbable:instanceThrownCollider()
  self.thrown_hitbox = self:addThrownCollider(self.collision_world:circle(self.pos.x, self.pos.y, 40), function() return self.ground_pos:unpack() end, 30, 1)
end

function Grabbable:getGrabbed(grab_collider)
  local signal = grab_collider.signal
  self.do_collision = false
  self.grabbed = true
  self.player = grab_collider.object
  self:cancelHeightTween()
  self.height = 0
  signal:emit('grab-success', self)
end

-- @param throw_dir digital representation of 8-way throw direction (a vector)
function Grabbable:getThrown(throw_dir)
  self.do_collision = true
  self:instanceThrownCollider()
  self.grabbed = false
  self.player = nil
  self.thrown = true
  self.height = 23
  -- here we're saving a *copy* of throw_dir to work with, so any changes to the REAL throw_dir variable in PlayerGrab don't affect the direction of the enemy.
  throw_direction = throw_dir:clone():normalizeInplace()
  --self.Move:setMovementSettings(vector(0,0), throw_direction * 2000, 100, 0.5, 2000)
  self.Move:setMovementSettings(nil, throw_direction * 900, 0, 0.66, 900)
  --print(self.Move.velocity)
  -- the velocity that the thrown entity will be at for the majority of the time in the thrown state is approximate, due to how the timer library works; the function isn't guaranteed to run exactly in 0.02 seconds, it's only guaranteed to run after 0.02 seconds have elapsed. This won't make a noticeable change in most cases, but it's still there.
  --self.Move.move_timer:tween(0.06, self.Move, {friction = 0}, 'in-linear', function() self.Move.move_timer:tween(0.2, self.Move, {friction = 0.65}, 'in-cubic') end)
  self.Move.move_timer:clear()
  self.Move.move_timer:tween(0.02, self.Move, {friction = 0.05}, 'in-cubic', 
    function() self.Move.move_timer:script(
      function(wait)
        self:setHeightTween(0.15, 0, 'in-cubic')
        wait(0.09)
        wait(0.09)
        --[[print(self.Move.velocity:len())]] 
        self.Move.move_timer:tween(0.02, self.Move, {friction = 0.6}) 
      end) 
  end)
 
  --self:setSuspense(4)
end

function Grabbable:onHit(seperating_vector, own_collider)
  own_collider.enabled = false
  -- shifts the thrown object's sprite rotation forward a bit, so if it hits on the first frame of being thrown, it will appear rotated
  self.Anim.sprite_rot = self.Anim.sprite_rot + (2 * math.pi / 3)
  -- version of setSuspese where the thrownCollider appears a bit after suspense is ended, found this doesn't add much.
  --self:setSuspense(own_collider.suspense, false, function() self.protected_timer:after(0.03, function() own_collider.enabled = true end) end)
  -- probably just better to let normal thrown entities only strike one enemy with a throw, so players have to aim properly.
  self:setSuspense(own_collider.suspense, false, function() own_collider.enabled = true end)
  self:bounceOffTarget(seperating_vector)
end

function Grabbable:onDink(seperating_vector, own_collider)
  self:bounceOffTarget(seperating_vector)
end

function Grabbable:finishThrow()
  self.thrown = false
  self.Anim:resetRotation()
  self.Move.move_timer:clear()
  for _,c in ipairs(self.colliders) do
    if c.tag == 'PlayerThrown' then self:removeCollider(c) end
  end
end   

-- used when the thrown entity bounces of scenery or collision tiles
function Grabbable:bounceOffEnvironment(separating_vector)
  
  local deflected_velocity = self:deflectMovementAngle(separating_vector, 0.75)
  self:moveTo(self.ground_pos + separating_vector)
  self.Move:setMovementSettings(nil, deflected_velocity, nil, nil, nil)
end

-- used when the thrown entity bounces of a target 
function Grabbable:bounceOffTarget(separating_vector)
  local deflected_velocity = self:deflectMovementAngle(separating_vector, 0.75)
  self:moveTo(self.ground_pos + separating_vector)
  self.Move.move_timer:clear()

  -- where the entity's current velocity falls within the possible range of velocities. A number between 0 and 1
  local vel_range = deflected_velocity:len() / (self.THROWN_MAX_VEL * 0.75)
  -- the amount of time it takes for the entity to tween to the ground. This is scaled based on vel_range
  local tween_time = 0.05 + (vel_range * 0.45)
  -- the amount of friction applied to entity when bouncing off a target. This is scaled based on vel_range
  local bounce_fric = 0.35 + ((1 - vel_range) * 0.05)
  
  self:setHeightTween(tween_time, 0, 'in-cubic')
  self.Move:setMovementSettings(nil, deflected_velocity, nil, bounce_fric, nil)
end

function Grabbable:updateRotationSpeed()
  local vel_range = self.Move.velocity:len() / self.THROWN_MAX_VEL
  self.Anim.rot_speed = vel_range * 5
  --self.Anim.rot_speed = self.Move.velocity:len() / 300
end

function Grabbable:deflectMovementAngle(separating_vector, vel_mod)
  local orig_dir = -(self.Move.velocity:clone())
  local deflected_velocity = self.Move.velocity:mirrorOn(separating_vector:perpendicular()) * vel_mod
  local deflect_angle = deflected_velocity:angleTo(orig_dir)
  -- if the deflection velocity is close enough in direction to the original velocity, it is rotated by a random value to keep thrown objects from bouncing right back in the player's face
  -- it also checks if the angle somehow rolled over to 2pi, which happens with certain collisions against tile colliders
  if math.abs(deflect_angle) < 0.3 or math.abs(deflect_angle) >= math.pi*2 then
    local angle_skew = self:generateAngleSkew()
    deflected_velocity:rotateInplace(angle_skew)
  end
  return deflected_velocity
end

--returns an angle between -50 and 50 degrees, but no less then approximately 8.5 degrees and no more than approximately -8.5 degrees
function Grabbable:generateAngleSkew()
  local angle_skew = math.random() * math.rad(50) * utilities.randomSign()
  return math.abs(angle_skew) > 0.15 and angle_skew or self:generateAngleSkew()
end

function Grabbable:breakOut(dir)
  self.do_collision = true
  self.grabbed = false
  self.player = nil
  if self.height > 0 then
    -- fall, then bounce
    self:setHeightTween(0.5, 0, 'in-cubic', function() self:jump(0.27, 30, 'quad', nil, 1.5) end)
  end
  self.Move:setMovementSettings(vector(0, 0), dir:normalizeInplace() * 900, 50, 0.55, 3000)
end

return Grabbable
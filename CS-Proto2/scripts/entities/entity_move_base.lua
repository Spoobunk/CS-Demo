Object = require "libs.classic.classic"

EntityMove = Object:extend()

function EntityMove:new(default_acc, default_fric, default_max_vel)
  self.direction = vector(0,0)
  self.velocity = vector(0,0)
  -- constants representing the 'default' movement values for whatever entity uses this component
  self.RUN_ACC = default_acc
  self.RUN_FRIC = default_fric
  self.RUN_MAX_VEL = default_max_vel
  -- variables used for calculating movement steps in any situation (knockback, while attacking, etc.)
  self.acceleration = self.RUN_ACC
  self.friction = self.RUN_FRIC
  self.max_velocity = self.RUN_MAX_VEL
  
  self.update_movement = true
  
  self.move_timer = Timer.new()
  -- a timer instance only used for height tweens
  self.height_timer = Timer.new()
end

function EntityMove:update(dt)
  self.move_timer:update(dt)
  self.height_timer:update(dt)
end

function EntityMove:getMovementStep(dt)
  if not self.update_movement then return vector(0, 0) end
  
  self.velocity = self.velocity + self.direction * self.acceleration
  
  if self.velocity:len() > self.max_velocity then
    self.velocity = self.velocity:normalized() * self.max_velocity
  end
  
  self.velocity = self.velocity * (1 - self.friction) ^ (dt * 10)
  
  return self.velocity * dt
  --self.velocity = self.velocity 
  --return vector(math.floor(self.velocity.x + 0.5), math.floor(self.velocity.y + 0.5)) * dt
end

-- higher fric = slower movement
-- lower acc = quicker movement 
-- to get slippery movement, you need to lower both friction and acceleration (I guess that means it's a pretty bad way of controlling movement but...)
function EntityMove:setMovementSettings(dir, vel, acc, fric, max_vel)
  self.direction = dir or self.direction
  self.velocity = vel or self.velocity
  self.acceleration = acc or self.acceleration
  self.friction = fric or self.friction
  self.max_velocity = max_vel or self.max_velocity
end

function EntityMove:defaultMovementSettings()
  self.acceleration = self.RUN_ACC
  self.friction = self.RUN_FRIC
  self.max_velocity = self.RUN_MAX_VEL
end

return EntityMove
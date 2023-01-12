--Player = require "scripts.player.player_state"
vector = require "libs.hump.vector"
Timer = require "libs.hump.timer"
Object = require "libs.classic.classic"
anim8 = require 'libs.anim8.anim8'

Player_Move = Object:extend()

--good settings: acc = 200, friction = 0.9, maxvel = 600
function Player_Move:new(state_manager)
  self.state_manager = state_manager

  self.direction = vector(0,0)
  -- source of truth for the direction the player is facing, 1 for right, -1 for left
  self.face_direction = 1
  -- digital vector keeping track of movement input at any given moment
  self.raw_input = vector(0,0)
  -- digital representation of movement input, for analog input it is approximated
  self.digital_input = vector(0,0)
  -- vector keeps track of latest movement input (it is never 0)
  self.last_input = vector(1,1)
    
  self.velocity = vector(0,0)
  -- constants that represent Stooba's normal movement, when runnin' around
  self.RUN_ACC = 155
  --self.RUN_ACC = 10
  self.RUN_FRIC = 0.85
  --self.RUN_FRIC = 0.95
  self.RUN_MAX_VEL = 600
  --self.RUN_MAX_VEL = 40
  -- variables used for calculating movement steps in any situation (knockback, while attacking, etc.)
  self.acceleration = self.RUN_ACC
  self.friction = self.RUN_FRIC
  self.max_velocity = self.RUN_MAX_VEL
  
  self.update_movement = true
  self.accepting_movement_input = true
  self.can_dodge_spin = true
  -- timer instance only for things related to movement
  self.move_timer = Timer.new()
    -- a timer instance only used for height tweens
  self.height_timer = Timer.new()
end

function Player_Move:update(dt, axis_x, axis_y) 
  self.move_timer:update(dt)
  self.height_timer:update(dt)
  
  self.raw_input = vector(axis_x, axis_y)
  local input_x = (axis_x == 0 and 0 or axis_x / math.abs( axis_x ))
  local input_y = (axis_y == 0 and 0 or axis_y / math.abs( axis_y ))
  
  local angle_simple = self.raw_input:normalized():angleTo(vector(1,0)) / math.rad(45)
  local digital_angle = (math.floor(math.abs(angle_simple) + 0.5) * utilities.sign(angle_simple)) * math.rad(45)
  self.digital_input = self.raw_input == vector(0,0) and vector(0,0) or vector.fromPolar(digital_angle)
  -- just cleaning up the digital input vector
  if math.abs(self.digital_input.x) < 0.001 then self.digital_input.x = 0 end
  if math.abs(self.digital_input.y) < 0.001 then self.digital_input.y = 0 end
  self.digital_input = vector(utilities.sign(self.digital_input.x), utilities.sign(self.digital_input.y))

  -- technically I could replace face_direction with last_input.x
  self.last_input = vector(input_x ~= 0 and input_x or self.last_input.x, input_y ~= 0 and input_y or self.last_input.y)
  self.face_direction = input_x ~= 0 and input_x or self.face_direction
  if self.state_manager.current_state.flip_sprite_horizontal then self.state_manager.player_components.anim:flipSpriteHorizontal(self.face_direction) else  end
    
  -- does running animation
  if(self.state_manager:Current_State_Is("idle")) then
    local anim = self.state_manager.player_components.anim
    if self.digital_input.x == 0 and self.digital_input.y == 0 then
      anim:Switch_Animation(anim.idle_anim)
    else
      anim:Switch_Animation(anim.walk_anim_matrix[2+self.digital_input.y][2+self.digital_input.x])
      anim.idle_anim = anim.idle_anim_matrix[2+self.digital_input.y][2+self.digital_input.x]
    end
  end
end

function Player_Move:get_movement_step(dt, axis_x, axis_y)
  -- if the move component is set not to update movement, an empty vector is returned, so collisions detection still takes place as normal
  if not self.update_movement then return vector(0, 0) end
 
  -- for states where the player can't control movement
  if(self.state_manager.current_state.canMove and self.accepting_movement_input) then
    self.direction = vector(axis_x,axis_y)
    --print(self.direction)
  end

  --move withouth acceleration
  --self.velocity = self.velocity + delta * self.max_velocity
  
  self.velocity = self.velocity + self.direction * self.acceleration
  
  if self.velocity:len() > self.max_velocity then
    self.velocity = self.velocity:normalized() * self.max_velocity
  end
  
  --[[ the problem here is that acceleration and friction didn't seem to work when using the line below for friction. 
  It seems the friction was so great that the beginning acceleration couldn't overcome it to build up speed. I replaced the math.min line with the line below it, 
  and got rid of '* dt' in the acceleration line. that seemed to fix the scaling so acceleration and friction could work together. However, it seems like there is 
  a hard cap on max velocity which depends on the friction value, which might be caused by the same problem I had before. Also, I'm not sure if removing 
  the dt multiplications would affect how this runs on other computers. ]]
  
   --self.velocity = self.velocity * (1 - math.min(dt * self.friction, 1))
   --self.velocity = self.velocity * (1 - self.friction)
   
   self.velocity = self.velocity * (1 - self.friction) ^ (dt * 10)
   --print(self.velocity * dt)
   --print(self.velocity:len())
  
  return self.velocity * dt
  --return vector(0, -10)
end

-- @param dir what to set the player's direction to (a normalized vector)
-- @param vel what to set the player's velocity to (a vector)
-- @param acc what to set the player's acceleration to (a number)
-- @param fric what to set the player's friction to (a number)
-- @param max_vel what to set the player's max velocity to (a number)
function Player_Move:Set_Movement_Settings(dir, vel, acc, fric, max_vel)
  self.direction = dir or self.direction
  self.velocity = vel or self.velocity
  self.acceleration = acc or self.acceleration
  self.friction = fric or self.friction
  self.max_velocity = max_vel or self.max_velocity
end

function Player_Move:defaultMovementSettings()
  self.acceleration = self.RUN_ACC
  self.friction = self.RUN_FRIC
  self.max_velocity = self.RUN_MAX_VEL
end

function Player_Move:getVelocity()
  return self.velocity
end

-- @param can boolean whether the player is accepting movement input or not (a boolean)
function Player_Move:Set_Movement_Input(can)
  self.accepting_movement_input = can
end

-- @param knockback_dir vector representing the direction of knockback (provided by collisions in player_state)
function Player_Move:Damaged_Knockback(knockback_dir, knockback_power)
  self.move_timer:clear()
  knockback_dir:normalizeInplace()
  self:Set_Movement_Settings(vector(0, 0), knockback_dir * knockback_power, 50, 0.55, 3000)
  self:Set_Movement_Input(false)
  
  self.move_timer:after(0.3, function() self.state_manager:change_states('idle') self:Set_Movement_Settings(vector(0, 0), false, self.RUN_ACC, self.RUN_FRIC, self.RUN_MAX_VEL) self.state_manager:setInputBuffering('all', false) end)
  self.move_timer:after(0.15, function() self:Set_Movement_Input(true) self.state_manager:setInputBuffering('all', true) end)
  self.state_manager:jump(0.1, 50, 'cubic', nil, 1)
end

function Player_Move:dodgeSpin()
  if not self.can_dodge_spin then return false end
  self.state_manager:change_states('spinning')
  self:Set_Movement_Input(false)
  self.move_timer:clear()
  if self.raw_input ~= vector(0, 0) then 
    local spin_dir = self.raw_input:normalized()
    self:Set_Movement_Settings(vector(0, 0), spin_dir * 1600, 10, 0.6, 3000)
    self.move_timer:after(0.2, function() self:Set_Movement_Settings(nil, nil, 10, 0.3, 3000) end)
    self.move_timer:after(0.05, function() self:Set_Movement_Input(true) end)
  end
  self.move_timer:after(0.30, function() self.state_manager:setInputBuffering('all', true) end)
  self.move_timer:after(0.35, function() 
    self.state_manager:change_states('idle') 
    self.state_manager:setInputBuffering('attack', false)
    self.state_manager:setInputBuffering('grab', false)
    self:Set_Movement_Settings(vector(0, 0), false, self.RUN_ACC, self.RUN_FRIC, self.RUN_MAX_VEL) 
    self:dodgeSpinCooldown()
  end)
end

function Player_Move:dodgeSpinCooldown()
  self.can_dodge_spin = false
  self.state_manager:addCancelTimer(0.12, function() return self.state_manager:Current_State_Is('idle') end, function() self.can_dodge_spin = true self.state_manager:setInputBuffering('spin', false) end)
end


return Player_Move
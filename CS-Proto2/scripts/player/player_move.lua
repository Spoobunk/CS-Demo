--Player = require "scripts.player.player_state"
vector = require "libs.hump.vector"
Timer = require "libs.hump.timer"
Object = require "libs.classic.classic"
anim8 = require 'libs.anim8.anim8'

Player_Move = Object:extend()

--good settings: acc = 200, friction = 0.9, maxvel = 600
function Player_Move:new(state_manager)
  --[[
  player_sheet = love.graphics.newImage('Sprites/Stuba/player_run.png')
  local g = anim8.newGrid(34, 50, player_sheet:getWidth(), player_sheet:getHeight(), 0, 0, 1)
  walk_down = anim8.newAnimation(g('1-4', 1), .1)
  walk_downright = anim8.newAnimation(g('5-6', 1, '1-2', 2), .1)
  walk_right = anim8.newAnimation(g('3-6', 2), .1)
  walk_upright = anim8.newAnimation(g('1-4', 3), .1)
  walk_up = anim8.newAnimation(g('5-6', 3, '1-2', 4), .1)
  walk_upleft = anim8.newAnimation(g('3-6', 4), .1)
  walk_left = anim8.newAnimation(g('1-4', 5), .1)
  walk_downleft = anim8.newAnimation(g('5-6', 5, '1-2', 6), .1)
  current_anim = walk_down
  idle_down = anim8.newAnimation(g(1, 1), .1)
  idle_animation = idle_down
  walk_anim_matrix = {
      {walk_upleft, walk_up, walk_upright},
      {walk_left, idle_animation, walk_right},
      {walk_downleft, walk_down, walk_downright}
    }]]
    
  self.state_manager = state_manager
  --print(state_manager.current_state.canMove)
  self.direction = vector(0,0)
  self.velocity = vector(0,0)
  -- constants that represent Stooba's normal movement, when runnin' around
  self.RUN_ACC = 200
  self.RUN_FRIC = 0.85
  self.RUN_MAX_VEL = 600
  -- variables used for calculating movement steps in any situation (knockback, while attacking, etc.)
  self.acceleration = self.RUN_ACC
  self.friction = self.RUN_FRIC
  self.max_velocity = self.RUN_MAX_VEL
  
  self.accepting_movement_input = true
  -- timer instance only for things related to movement
  self.move_timer = Timer.new()
end

function Player_Move:update(dt) 
  self.move_timer:update(dt)
end

function Player_Move:get_movement_step(dt, axis_x, axis_y)
    
  --local direction = vector(0, 0)
 
  -- for states where the player can't control movement
  if(self.state_manager.current_state.canMove and self.accepting_movement_input) then
    self.direction = vector(axis_x,axis_y)
  end
  
  -- does running animation
  if(self.state_manager:Current_State_Is("idle")) then
    local input_x = (axis_x == 0 and 0 or axis_x / math.abs( axis_x ))
    local input_y = (axis_y == 0 and 0 or axis_y / math.abs( axis_y ))
    local anim = self.state_manager.player_components.anim
    if input_x == 0 and input_y == 0 then
      anim:Switch_Animation(anim.idle_anim)
    else
      anim:Switch_Animation(anim.walk_anim_matrix[2+input_y][2+input_x])
      anim.idle_anim = anim.idle_anim_matrix[2+input_y][2+input_x]
    end
  end
  
  --no need to normalize, the input values are already normalized by the input library
  --delta:normalizeInplace()
  
  --move withouth acceleration
  --self.velocity = self.velocity + delta * self.max_velocity
  
  self.velocity = self.velocity + self.direction * self.acceleration
  
  if self.velocity:len() > self.max_velocity then
    self.velocity = self.velocity:normalized() * self.max_velocity
  end
  
  --[[ the problem here is that acceleration and friction didn't seem to work when using the line below for friction. 
  It seems the friction was so great that the beginning acceleration couldn't overcome it to build up speed. I replaced the math.min line with the line below it, 
  and got rid of '* dt' in the acceleration line. that seemed to fix the scaling so acceleration and friction could work together. However, it seems like there is 
  a hard cap on the max_velocity value which depends on the friction value, which might be caused by the same problem I had before. Also, I'm not sure if removing 
  the dt multiplications would affect how this runs on other computers. ]]
  
  --self.velocity = self.velocity * (1 - math.min(dt * self.friction, 1))
   --self.velocity = self.velocity * self.friction
   self.velocity = self.velocity * (1 - self.friction) ^ (dt * 10)
  
  return self.velocity * dt
end

function Player_Move:spin()
  --local anim = self.state_manager.player_components.anim
  --anim:Switch_Animation("anim_test")
  self.state_manager:change_states('moving') 
  local hitbox = self.state_manager.collision_world:circle(self.state_manager.position.x + 30, self.state_manager.position.y, 40)
  self.state_manager:addCollider(hitbox, "Player_Attack", self.state_manager, function() return self.state_manager.position.x + 30, self.state_manager.position.y end)
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

-- @param can whether the player is accepting movement input or not (a boolean)
function Player_Move:Set_Movement_Input(can)
  self.accepting_movement_input = can
end

-- @param knockback_dir vector representing the direction of knockback (provided by collisions in player_state)
function Player_Move:Damaged_Knockback(knockback_dir)
  knockback_dir:normalizeInplace()
  self:Set_Movement_Settings(vector(0, 0), knockback_dir * 1700, 50, 0.55, 3000)
  self:Set_Movement_Input(false)
  self.move_timer:clear()
  self.move_timer:after(0.3, function() self:Set_Movement_Settings(vector(0, 0), false, self.RUN_ACC, self.RUN_FRIC, self.RUN_MAX_VEL) end)
  self.move_timer:after(0.05, function() self:Set_Movement_Input(true) end)
end
  

return Player_Move
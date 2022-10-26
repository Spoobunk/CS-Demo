Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"
S = require "libs.strike"
anim8 = require 'libs.anim8.anim8'
Timer = require "libs.hump.timer"

Move = require "scripts.player.player_move"
Anim = require "scripts.player.player_anim"
Attack = require "scripts.player.player_attack"
Health = require "scripts.player.player_health"
Grab = require "scripts.player.player_grab"

Entity = require "scripts.entities.entity_base"

Player = Entity:extend()

local path_to_states = "scripts.player.player states."

-- list of all player states
Player.player_states = {
    idle = require (path_to_states .. "idle_state"),
    moving = require (path_to_states .. "moving_state"),
    attacking = require (path_to_states .. "attack_state"),
    hitstun = require (path_to_states .. "hitstun_state"),
    spinning = require (path_to_states .. "spinning_state"),
    holding = require (path_to_states .. "holding_state"), 
    grabbing = require (path_to_states .. "grabbing_state"),
    throwing = require (path_to_states .. "throwing_state"),
    dormant = require (path_to_states .. "dormant_state")
}
-- fills in the list with the actual state classes
 --for name in pairs(Player.player_states) do
    --player_states[name] = require "scripts.player.player states." .. name
  --end
-- @param collision_world: world for entity collisions, seperate from tilemap collisions
-- @param tile_world: world for tilemap collisions
function Player:new(x, y, collision_world, tile_world)
  Player.super.new(self, x, y, collision_world, tile_world)
  self.name = "Player"
  self.current_state = Player.player_states.idle
  local move_component = Move(self)
  local anim_component = Anim(self)
  local attack_component = Attack(self)
  local health_component = Health(self)
  local grab_component = Grab(self)
  self.player_components = {move = move_component, anim = anim_component, attack = attack_component, health = health_component, grab = grab_component}
  self.Move = move_component
  self.Anim = anim_component
  
  self.camera = nil -- camera reference, set in game_state.lua
  
  --self.img = love.graphics.newImage("assets/basic/sprites/player/stuba test.png")
  self.position = vector(x, y) or vector(0, 0)
  self.ground_pos = self.position
  self.current_movestep = vector(0, 0)
  self.base_image_offset = vector(30 / 2, 52 / 2)
  -- 31 by 51: dimensions for stooba's standing sprite sheet, to establish where their feet lie
  -- i.e.: stuba's idle, standing animation is drawn (31/2) pixels left and (51/2) above their actual position, so it is centered.
  
  -- a timer that won't ever be cleared
  self.protected_timer = Timer.new()
  self.buffered_input = nil
  self.is_buffering_input = {attack = false, grab = false, spin = false}
  -- keeps track of what inputs are being held down
  self.is_holding_input = {attack = false, grab = false, spin = false}
  
  self.in_suspense = false
  
  self.cancel_timers = {}
  
  self.collision_world = collision_world
  self.collider = self.collision_world:circle(self.position.x, self.position.y, 20)
  self.test_guy = self.collision_world:rectangle(400, 400, 100, 100)
  self.test_guy2 = self.collision_world:circle(100, 300, 100)
  self:addCollider(self.collider, "Player", self, function() return self.ground_pos:unpack() end)
  self:addCollider(self.test_guy, "Reflect", self, function() return 400, 0 end)
  self:addCollider(self.test_guy2, "Test", self, function() return 100, 300 end)

  self.setUpTileCollider(self, self.position.x, self.position.y, 12, -1, 25, 24)
  
  self.collision_resolution = {
    Player = {--Test = function(separating_vector) self.player_components.move:Damaged_Knockback(vector(separating_vector.x, separating_vector.y), 1700) end,
              Test = function(separating_vector) self:moveTo(self.ground_pos + vector(separating_vector.x, separating_vector.y)) end,
              Enemy = function(separating_vector, other) if(not other.object:currentStateIs('hitstun')) then self.player_components.health:takeDamage(separating_vector, other) end end}
  }
  -- these are conditions that the collisions resolution system checks before resolving collisions. the conditions of each party is checked. if either returns false, then no resolution is done on either party.
  self.collision_condition = {
    Player = {Enemy = function() return self.player_components.health:isVulnerable() end}
  }
end

function Player:change_states(to)
  -- saves the stat the player is transitioning from
  local from_state = self.current_state
  -- switch states
  self.current_state = Player.player_states[to]
  -- calls the exit function on the transitioning state
  if  from_state.exit then  from_state.exit(self, self.current_state) end
  -- calls the enter function on the new state, with the from state as an optional parameter
  self.current_state.enter_state(self, from_state)
    
  self:updateCancelTimers()
    
  -- resets the input buffer when an action state is entered
  if not self:Current_State_Is('idle') and not self:Current_State_Is('holding') then 
    self:clearInputBuffer()
  end
end

function Player:Current_State_Is(state)
  return self.current_state == Player.player_states[string.lower(state)]
end

function Player:Get_Current_State()
  return self.current_state.name
end
  
-- function that is called when the player presses once of the action buttons (attack, spin, grab, etc). It looks up the correct function to call based on the state the player is currently in.
-- action must be a string
function Player:input_button(action)
  -- retrieves a table (or nil) containing the name of the function [2] and the player component it is in [1]
  local requested_function = self.current_state.input[action]
  -- checks if the value retrieved is nil, in which case nothing should be done, as that input does't have any consequence in this state
  if requested_function then
    local component, action = requested_function[1], requested_function[2]
    -- retrieves the correct player component...
    local script = self.player_components[component]
    -- ...then calls the function.
    script[action](script)
  end

  --[[ bracket notation is used instead of dot notation when indexing tables/calling functions because we are working with parameters here, hence we don't know what value we'll be looking for.
  dot notation only works if the name of the variable matches up with the value we are looking to index.]]

  --if self.is_buffering_input[action] then self.buffered_input = action print('buffer ' .. action) elseif not string.find(action, 'release_') then print('initiate ' .. action) end
  if self.is_buffering_input[action] then self.buffered_input = action end
  
  -- updates is_holding_input variables
  if string.find(action, 'release_') then 
    _, j = string.find(action, 'release_')
    local input_name = string.sub(action, j+1)
    self.is_holding_input[input_name] = false
  else 
     self.is_holding_input[action] = true
  end
    
end

-- @param which represents which buffer to set (a string, being 'attack', 'move', 'grab' or 'all')
-- @param setting a boolean representing whether the buffer is active or not (a boolean)
function Player:setInputBuffering(which, setting)
  if which == 'all' then
    for k,_ in pairs(self.is_buffering_input) do
      self.is_buffering_input[k] = setting
    end
  else
    self.is_buffering_input[which] = setting
  end
end

function Player:clearInputBuffer()
  self.buffered_input = nil
  self:setInputBuffering('all', false)
end

function Player:addCancelTimer(time, condition, action)
  local ct = {}
  ct.action = function() action() self:removeCancelTimer(ct.handle) end
  ct.condition = condition
  ct.handle = self.protected_timer:after(time, ct.action)
  table.insert(self.cancel_timers, ct)
  return ct
end

function Player:removeCancelTimer(handle)
  for i, ct in ipairs(self.cancel_timers) do
    if ct.handle == handle then table.remove(self.cancel_timers, i) end
  end
end

function Player:updateCancelTimers()
  for i = #self.cancel_timers, 1, -1 do 
    local ct = self.cancel_timers[i]
    if not ct.condition() then self.protected_timer:cancel(ct.handle) ct.action() end
  end
end

-- @param t number duration of suspense
-- @param after_func optional function parameter that gets run when suspense is ended
function Player:setSuspense(t, can_move, after_func)
  self.in_suspense = true
  local this_state = self.current_state
  if can_move then
    self:addCancelTimer(t, function() return self.current_state == this_state end, function() self.in_suspense = false if after_func then after_func() end end)
  else
    self.player_components.move.update_movement = false
    self:addCancelTimer(t, function() return self.current_state == this_state end, function() self.in_suspense = false self.player_components.move.update_movement = true if after_func then after_func() end end)
  end
end

function Player:draw()
  self.player_components.anim:draw(self.position.x, self.position.y)
  --draw box around current frame
  --self.player_components.anim:drawFrameBox(self.position.x, self.position.y)
  
  --self:drawRenderPosition()
  --self:drawTileCollider()
  love.graphics.setColor(255, 0, 0, 1)
  -- drawing absolute position
  love.graphics.points(self.position.x, self.position.y)
  love.graphics.setColor(0, 0, 255, 1)

  --self:drawColliders()
  love.graphics.setColor(255, 255, 255, 1)
end

function Player:update(dt, move_input_x, move_input_y) 
  for name, component in pairs(self.player_components) do
    if (name == 'attack' or name == 'anim' or name == 'move') and self.in_suspense then 

    else
      component:update(dt, move_input_x, move_input_y)
    end
  end

  self.protected_timer:update(dt)
  if self.buffered_input and not self.is_buffering_input[self.buffered_input] then self:input_button(self.buffered_input) self.buffered_input = nil end
  self:updateCancelTimers()
    
  local last_pos = self.ground_pos
  
  --player's custom version of the movement segment of Entity.update()
  --if not self.in_suspense then
    local move_step = self.player_components.move:get_movement_step(dt, move_input_x, move_input_y)
    --print(move_step)
    --move_step = vector(math.floor(move_step.x + 0.5), math.floor(move_step.y + 0.5))
    --print(move_step)
    local goal_pos = (self.ground_pos + move_step) - self.tile_collider_offset
    local actualX, actualY, cols, len = self.tile_world:move(self, goal_pos.x, goal_pos.y, function(item, other) return self:checkTileCollisionForHeight(item, other) end)
  
    self.ground_pos = vector(actualX, actualY) + self.tile_collider_offset
    
    self.position = self.ground_pos - vector(0, self.height)
    self.pos = self.position
  --end
  
  self:updateColliderPositions()
  self:resolveCollisions()
  self:updateColliderPositions()
  
  --self.ground_pos = vector(math.floor(self.ground_pos.x + 0.5), math.floor(self.ground_pos.y + 0.5))
  self.position = self.ground_pos - vector(0, self.height)
  self.pos = self.position
  self.current_movestep = self.ground_pos - last_pos
  --if not self.in_suspense then self.current_movestep = self.ground_pos - last_pos else self.current_movestep = vector(0, 0) end
end

function Player:getRenderPosition()
  oy = self.player_components.anim:Get_Base_Image_Offset().y
  return math.floor(((self.position.y + self.height) + oy) + 0.5)
end

return Player 
  
   
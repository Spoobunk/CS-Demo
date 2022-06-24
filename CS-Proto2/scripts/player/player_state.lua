Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"
S = require "libs.strike"
anim8 = require 'libs.anim8.anim8'

Move = require "scripts.player.player_move"
Anim = require "scripts.player.player_anim"
Attack = require "scripts.player.player_attack"

Entity = require "scripts.entities.entity_base"

Player = Entity:extend()

local path_to_states = "scripts.player.player states."

-- list of all player states
Player.player_states = {
    idle = require (path_to_states .. "idle_state"),
    moving = require (path_to_states .. "moving_state"),
    attacking = require (path_to_states .. "attack_state")
}

-- fills in the list with the actual state classes
 --for name in pairs(Player.player_states) do
    --player_states[name] = require "scripts.player.player states." .. name
  --end
-- @param collision_world: world for entity collisions, seperate from tilemap collisions
-- @param tile_world: world for tilemap collisions
function Player:new(x, y, collision_world, tile_world)
  Player.super.new(self, x, y, collision_world, tile_world)
  self.name = "player"
  self.current_state = Player.player_states.idle
  local move_component = Move(self)
  local anim_component = Anim(self)
  local attack_component = Attack(self)
  self.player_components = {move = move_component, anim = anim_component, attack = attack_component}
  self.Move = move_component
  self.Anim = anim_component
  
  --self.img = love.graphics.newImage("assets/basic/sprites/player/stuba test.png")
  self.position = vector(x, y) or vector(0, 0)
  self.ground_pos = self.position
  self.current_movestep = vector(0, 0)
  self.base_image_offset = vector(30 / 2, 52 / 2)
  -- 31 by 51: dimensions for stooba's standing sprite sheet, to establish where their feet lie
  -- i.e.: stuba's idle, standing animation is drawn (31/2) pixels left and (51/2) above their actual position, so it is centered.
  
  self.collision_world = collision_world
  self.collider = self.collision_world:circle(self.position.x, self.position.y, 20)
  self.test_guy = self.collision_world:rectangle(400, 400, 100, 100)
  self.test_guy2 = self.collision_world:circle(100, 300, 100)
  self:addCollider(self.collider, "Player", self, function() return self.position:unpack() end)
  self:addCollider(self.test_guy, "Test", self, function() return 400, 0 end)
  self:addCollider(self.test_guy2, "Test", self, function() return 100, 300 end)

  self.setUpTileCollider(self, self.position.x, self.position.y, 12, -1, 25, 24)
  
  self.collision_resolution = {
    Player = {Test = function(separating_vector) self.player_components.move:Damaged_Knockback(vector(separating_vector.x, separating_vector.y)) end,
              --[[{Test = function(separating_vector) if not self.cool then print(separating_vector.y) print(self.position) 
                  local this_x = self.position.x
                  local this_y = self.position.y
                  self:addCollider(self.collision_world:circle(self.position.x, self.position.y, 20), "noddu", self, function() return this_x, this_y end)
                  self:moveTo(self.position + vector(separating_vector.x, separating_vector.y)) print(self.position) self.cool = true self.player_components.move:Set_Movement_Input(false) self.player_components.move:Set_Movement_Settings(vector(0, 0), vector(0,0), 0, 0, 0) end end,]]
              --{Test = function(separating_vector) self:moveTo(self.position + vector(separating_vector.x, separating_vector.y)) end,
              Enemy = function(separating_vector, other) if(not other.object:currentStateIs('hitstun')) then self.player_components.move:Damaged_Knockback(vector(separating_vector.x, separating_vector.y)) end end}
  }
end

function Player:change_states(to)
  -- saves the stat the player is transitioning from
  local from_state = self.current_state
  -- switch states
  self.current_state = Player.player_states[to]
  -- calls the enter function on the new state, with the from state as an optional parameter
  self.current_state.enter_state(from_state)
end

function Player:Current_State_Is(state)
  return self.current_state == Player.player_states[state]
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
end

function Player:draw()
  self.player_components.anim:draw(self.position.x, self.position.y)
  --draw box around current frame
  --self.player_components.anim:drawFrameBox(self.position.x, self.position.y)
  
  self:drawRenderPosition()
  --self:drawTileCollider()
  love.graphics.setColor(255, 0, 0, 1)
  -- drawing absolute position
  love.graphics.points(self.position.x, self.position.y)
  love.graphics.setColor(0, 0, 255, 1)

  self:drawColliders()
  love.graphics.setColor(255, 255, 255, 1)
end

function Player:update(dt, move_input_x, move_input_y)  
  for _, component in pairs(self.player_components) do
    component:update(dt)
  end
  
  local last_pos = self.ground_pos
  
  --player's custom version of the movement segment of Entity.update()
  local move_step = self.player_components.move:get_movement_step(dt, move_input_x, move_input_y)
  local goal_pos = (self.ground_pos + move_step) - self.tile_collider_offset
  local actualX, actualY, cols, len = self.tile_world:move(self, goal_pos.x, goal_pos.y, function(item, other) return self:checkTileCollisionForHeight(item, other) end)
  
  self.ground_pos = vector(actualX, actualY) + self.tile_collider_offset
  -- this line simply sets the horizontal velocity of the player to 0 whent running into a wall, so when hitting an enemy it doesn't copy the players velocity when running into a wall
  if actualX - goal_pos.x ~= 0 then self.player_components.move.velocity.x = 0 end
  self.position = self.ground_pos - vector(0, self.height)
  self.pos = self.position
  -- rounding position values makes you get stuck on colliders :/
  --self.position = vector(math.floor(self.position.x), math.floor(self.position.y))
  
  self:updateColliderPositions()
  self:resolveCollisions()
  self:updateColliderPositions()
  
  self.current_movestep = self.ground_pos - last_pos
end

function Player:getRenderPosition()
  oy = self.player_components.anim:Get_Base_Image_Offset().y
  return math.floor(((self.position.y + self.height) + oy) + 0.5)
end

return Player 
  
   
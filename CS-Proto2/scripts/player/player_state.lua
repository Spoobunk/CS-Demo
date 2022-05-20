Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"
S = require "libs.strike"
anim8 = require 'libs.anim8.anim8'

Move = require "scripts.player.player_move"
Anim = require "scripts.player.player_anim"

Entity = require "scripts.entities.entity_base"

Player = Entity:extend()

local path_to_states = "scripts.player.player states."

-- list of all player states, to be filled in with a for loop
Player.player_states = {
    idle = require (path_to_states .. "idle_state"),
    moving = require (path_to_states .. "moving_state")
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
  self.player_components = {move = move_component, anim = anim_component}
  --self.player_components[move] = new
  self.test_img = love.graphics.newImage("assets/test/sprites/sprite_pos_test.png")
  self.img = love.graphics.newImage("assets/basic/sprites/player/stuba test.png")
  self.position = vector(x, y) or vector(0, 0)
  self.ground_pos = self.position
  self.base_image_offset = vector(30 / 2, 52 / 2)
  -- 31 by 51: dimensions for stooba's standing sprite sheet, to establish where their feet lie
  -- i.e.: stuba's idle, standing animation is drawn (31/2) pixels left and (51/2) above their actual position, so it is centered.
  
  --self.sprite_pos = self.position - self.image_offset
  
  self.collision_world = collision_world
  self.collider = self.collision_world:circle(self.position.x, self.position.y, 50)
  --self.collider.tag = "Player"
  --self.collider.object = self
  self:addCollider(self.collider, "Player", self, function() return self.position:unpack() end)
  self.test_guy = self.collision_world:rectangle(400, 400, 100, 100)
  self.test_guy2 = self.collision_world:circle(100, 300, 100)
  --self.test_guy.tag = 'Test'
  --self.test_guy2.tag = 'Test'
  self:addCollider(self.test_guy, "Test", self, function() return 400, 400 end)
  self:addCollider(self.test_guy2, "Test", self, function() return 100, 300 end)


  --self.tile_world = tile_world
  -- the the x, y coords of the tile_collider relative to the player's pos
  --self.tile_collider_offset = vector(12, -1)
  -- sets up the tile collider
  --self.tile_collider = self.tile_world:add(self, self.position.x - self.tile_collider_offset.x, self.position.y - self.tile_collider_offset.y, 25, 24)
  self.setUpTileCollider(self, self.position.x, self.position.y, 12, -1, 25, 24)
  self.collision_resolution = {
    Player = {Test = function(separating_vector) self.player_components.move:Damaged_Knockback(vector(separating_vector.x, separating_vector.y)) end }
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
  --love.graphics.draw(self.img, sprite_pos:unpack())
  --local s, v = (self.position - self.image_offset):unpack()
  --[[
  local s, v = self.position:unpack()
  s = math.ceil(s)
  v = math.ceil(v)
  
  --v = v - (self.test_img:getHeight() - self.image_offset.y*2)
  --s = s - (self.test_img:getWidth()/2 - self.image_offset.x)
  frameW, frameH = self.player_components.anim:Get_Frame_Dimensions()

  print(frameH .. " " .. (frameH - self.image_offset.y))
  v = v - (frameH - self.image_offset.y)
  s = s - (frameW/2)
  s = math.floor(s)
  v = math.floor(v)
  --]]
  self.player_components.anim:draw(self.position.x, self.position.y)

  --love.graphics.draw(self.test_img, s, v)
  love.graphics.line(self.position.x - 30, self:getRenderPosition(), self.position.x + 30, self:getRenderPosition())
  self:drawTileCollider()
  love.graphics.setColor(255, 0, 0, 1)
  -- drawing absolute position
  --love.graphics.points(self.position.x, self.position.y)
  love.graphics.setColor(0, 0, 255, 1)

  -- drawing hardon colliders
  self:drawColliders()
  love.graphics.setColor(255, 255, 255, 1)
end

function Player:update(dt, move_input_x, move_input_y)
  --[[
  for _, component in ipairs(self.player_components) do
    component:update(dt)
  end]]
  self.player_components.anim:update(dt)
  self.player_components.move:update(dt)
  
  --player's custom version of the movement segment of Entity.update()
  local move_step = self.player_components.move:get_movement_step(dt, move_input_x, move_input_y)
  local goal_pos = (self.ground_pos + move_step) - self.tile_collider_offset
  local actualX, actualY, cols, len = self.tile_world:move(self, goal_pos.x, goal_pos.y, function() return self:checkTileCollisionForHeight() end)
  self.ground_pos = vector(actualX, actualY) + self.tile_collider_offset
  self.position = self.ground_pos - vector(0, self.height)

 -- local move_step = self.player_components.move:get_movement_step(dt, move_input_x, move_input_y)
  -- moves the player while taking tile collisions into account
  --local goal_pos = (self.position + move_step) - self.tile_collider_offset
  --local actualX, actualY, cols, len = self.tile_world:move(self, goal_pos.x, goal_pos.y)
  --self.position = vector(actualX, actualY) + self.tile_collider_offset

  self:updateColliderPositions()
  self:resolveCollisions()
  --[[
  local collisions = self.collision_world:collisions(self.collider)
  for other, separating_vector in pairs(collisions) do
    if(other.tag == "Test") then
      --self.position = vector(self.collider:center())
      self.player_components.move:Damaged_Knockback(vector(separating_vector.x, separating_vector.y))
      --other:move(-separating_vector.x/2, -separating_vector.y/2)
    end
  end
  ]]
  
  --self.sprite_pos = self.position - self.image_offset
  --self.hit:translate(move_step:unpack())
  --[[
  if S.triking(self.hit, self.test_box) then
    --this allows stooba to push colliders, halving their speed
    S.hove(S.triking(self.hit, self.test_box))
    local new_pos = self.hit.centroid
    self.position.x = new_pos.x
    self.position.y = new_pos.y
    -- doesn't really work
    self.position = self.position - vector(S.triking(self.hit, self.test_box).x, S.triking(self.hit, self.test_box).y)
    self.hit:translate(S.triking(self.hit, self.test_box).x, S.triking(self.hit, self.test_box).y)
  end
  ]]
end

function Player:getRenderPosition()
  oy = self.player_components.anim:Get_Base_Image_Offset().y
  return math.floor(((self.position.y + self.height) + oy) + 0.5)
end

return Player 
  
  
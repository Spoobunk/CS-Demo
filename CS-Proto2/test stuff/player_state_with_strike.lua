Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"
S = require "libs.strike"
Move = require "scripts.player.player_move"

Player = Object:extend()

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

function Player:new(x, y)
  self.current_state = Player.player_states.idle
  local move_component = Move(self)
  self.player_components = {move = move_component}
  --self.player_components[move] = new
  self.img = love.graphics.newImage("assets/basic/sprites/player/stuba test.png")
  self.position = vector(x, y) or vector(0, 0)
  self.image_offset = vector(self.img:getWidth() / 2, self.img:getHeight() / 2)
  self.hit = S.trikers.Circle(x, y, self.img:getWidth())
  self.test_box = S.trikers.Rectangle(500, 500, 50, 50)
end

function Player:change_states(to)
  -- saves the stat the player is transitioning from
  local from_state = self.current_state
  -- switch states
  self.current_state = Player.player_states[to]
  -- calls the enter function on the new state, with the from state as an optional parameter
  self.current_state.enter_state(from_state)
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
    script[action]()
  end
  --[[ bracket notation is used instead of dot notation when indexing tables/calling functions because we are working with parameters here, hence we don't know what value we'll be looking for.
  dot notation only works if the name of the variable matches up with the value we are looking to index.]]
end

function Player:draw()
  local sprite_pos = self.position - self.image_offset
  love.graphics.draw(self.img, sprite_pos:unpack())
  love.graphics.setColor(0, 0, 255, 1)
  love.graphics.rectangle("fill", self.position.x, self.position.y, 10, 10)
  love.graphics.setColor(255, 0, 0, 1)
  self.hit:draw()
  self.test_box:draw()
  love.graphics.setColor(255, 255, 255, 1)
end

function Player:update(dt, move_input_x, move_input_y)
  
  local move_step = self.player_components.move:get_movement_step(dt, move_input_x, move_input_y)
  self.position = self.position + move_step
  self.hit:translate(move_step:unpack())
  
  if S.triking(self.hit, self.test_box) then
    --this allows stooba to push colliders, halving their speed
    S.hove(S.triking(self.hit, self.test_box))
    local new_pos = self.hit.centroid
    self.position.x = new_pos.x
    self.position.y = new_pos.y
    -- doesn't really work
    --[[self.position = self.position - vector(S.triking(self.hit, self.test_box).x, S.triking(self.hit, self.test_box).y)
    self.hit:translate(S.triking(self.hit, self.test_box).x, S.triking(self.hit, self.test_box).y)]]
  end
end


return Player 
  
  
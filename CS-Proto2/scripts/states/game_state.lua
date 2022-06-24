Gamestate = require "libs.hump.gamestate"
Camera = require "libs.hump.camera"
Timer = require "libs.hump.timer"
gamera = require 'libs.gamera.gamera'
Object = require "libs.classic.classic"
Player = require "scripts.player.player_state"
e_test = require "scripts.entities.entity_test"
entity_manager = require "scripts.entity_manager"
baton = require "libs.baton.baton"
bump = require "libs.bump.bump"
HC = require "libs.hardoncollider"
STI = require "libs.STI.sti"
gscreen = require "libs.pixel.pixel"
gscreen.load(2)
gscreen.toggle_fullscreen()

et = require "scripts.entities.enemies.enemy_test"

--might make this its own class
--ActiveState = Object:extend()
--ActiveState.state = game_state
local p
local game_state = {}
local entity_collision = HC.new(100)

--gamepad buttons are oriented based on a standard xbox 360 controller (if the controller is recognized as a standard gamepad)
local input = baton.new {
  controls = {
    left = {'key:left', 'key:a', 'axis:leftx-', 'button:dpleft'},
    right = {'key:right', 'key:d', 'axis:leftx+', 'button:dpright'},
    up = {'key:up', 'key:w', 'axis:lefty-', 'button:dpup'},
    down = {'key:down', 'key:s', 'axis:lefty+', 'button:dpdown'},
    attack = {'key:z', 'button:x'},
    spin = {'key:x', 'button:a'},
    grab = {'key:c', 'axis:triggerleft+', 'axis:triggerright+'}
  },
  pairs = {
    move = {'left', 'right', 'up', 'down'}
  },
  joystick = love.joystick.getJoysticks()[1],
}

function game_state:enter()
  love.graphics.setDefaultFilter("nearest", "nearest", 1)
  love.graphics.setLineStyle("rough")

  local tile_world = bump.newWorld(48)
  map = STI("assets/test/maps/test_map.lua", {"bump"})
  map:bump_init(tile_world)
  local entity_layer = map:addCustomLayer("Entities", 3)
  local test_layer = map:addCustomLayer("Test", 3)
  player_spawnx, player_spawny = map.objects[1].x, map.objects[1].y
  
  p = Player(player_spawnx, player_spawny, entity_collision, tile_world)
  camera = Camera(p.position.x + 200, p.position.y + 200)
  scaling_factor = {s = 1}

  --gam = gamera.new(0, 0, 2000, 2000)
  --gam:setPosition(p.position.x, p.position.y)
  
  --camera boundaries: the extents of the tilemap + half the viewport
  
 
  entity_layer.tower = {sprite = tower_sprite, x = 50, y = 50}
  
  entity_layer.player = p
  
 
  --test_layer.draw = function(self) love.graphics.draw(tower_sprite, 50, 50) end
  map:removeLayer("Object Layer 1")
    
  --table.insert(entities, p)
  
  test_img = love.graphics.newImage("assets/basic/sprites/player/stuba test.png")
  test_timer = Timer.new()
  
  
  
  local e_boy = e_test(50, 50)
  e_guy = et(0, 0, entity_collision, tile_world)
  e_gut = et(0, 300, entity_collision, tile_world)
  e_gur = et(0, 300, entity_collision, tile_world)
  e_gue = et(0, 300, entity_collision, tile_world)
  e_guw = et(0, 300, entity_collision, tile_world)
  e_guq = et(0, 300, entity_collision, tile_world)
  e_guz = et(0, 300, entity_collision, tile_world)
  e_gux = et(0, 300, entity_collision, tile_world)
  e_guc = et(0, 300, entity_collision, tile_world)
  entity_manager:addEntity(e_boy)
  entity_manager:addEntity(e_guy)
  entity_manager:addEntity(e_gut)
  entity_manager:addEntity(e_gur)
  entity_manager:addEntity(e_gue)
  entity_manager:addEntity(e_guw)
  entity_manager:addEntity(e_guq)
  entity_manager:addEntity(e_guz)
  entity_manager:addEntity(e_gux)
  entity_manager:addEntity(e_guc)
  entity_manager:addEntity(p)


  entity_layer.draw = function(self) entity_manager.drawEntities() end
end

--function game_state:keypressed()

--end

function game_state:update(dt)
  input:update()
  test_timer:update(dt)
  
  if input:pressed('attack') then
    p:input_button('attack')
  end
  
  if input:pressed('spin') then
    test_timer:clear()
    if zoom_tween == nil then 
      zoom_tween = test_timer:tween(1, scaling_factor, {s = 2}, "out-quad") 
    else 
      zoom_tween = test_timer:tween(1, scaling_factor, {s = 1}, "out-quad", function() zoom_tween = nil end)
    end
    
    --p:input_button('spin')
  end
  
  if input:pressed('grab') then
    p:input_button('grab')
  end
  
  movex, movey = input:get('move')
  p:update(dt, movex, movey)
  entity_manager.updateEntities(dt)
  entity_manager:updateRenderOrder()
  
  local dx,dy = p.position.x - camera.x, p.position.y - camera.y
  camera:move(dx, dy)
  camera:zoomTo(scaling_factor.s)

  map:update(dt)
  gscreen.update(dt)
end

function game_state:draw()
  
    
  gscreen.start()
  --gam:draw(function()
    camera:attach(0, 0, love.graphics.getWidth() / gscreen.scale, love.graphics.getHeight() / gscreen.scale, "noclip")
    --love.graphics.draw(test_img, p.position.x, p.position.y)
    --for some reason drawing the player from its own draw method results in weird jumpled sprites, while drawing directly in this method looks fine.
    --p.player_components.anim:draw(p.position.x, p.position.y)
    --camera:attach()
    --local tx = math.floor(p.position.x - (love.graphics.getWidth() / gscreen.scale)  / 2)
    --local ty = math.floor(p.position.y - (love.graphics.getHeight() / gscreen.scale) / 2)
    --map:draw(-tx, -ty)
    map:draw()
    --love.graphics.print("Is it working" .. type(Player), 20, 20)
    --p:draw()
    --for _,e in ipairs(entities) do e:draw() end
    camera:detach()
  --end)
  gscreen.stop()
  love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
  
end

function game_state:keyreleased()
  --Gamestate.switch(state_manager.menu)
end
  

return game_state
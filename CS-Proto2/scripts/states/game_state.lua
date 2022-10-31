Gamestate = require "libs.hump.gamestate"
Camera = require "libs.hump.camera"
Stalker = require "libs.STALKER-X.Camera"
Timer = require "libs.hump.timer"
Object = require "libs.classic.classic"
Player = require "scripts.player.player_state"
CameraWrapper = require "scripts.camera.camera"
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
ebt = require "scripts.entities.enemies.enemy_bounce_test"

--might make this its own class
--ActiveState = Object:extend()
--ActiveState.state = game_state
local NATIVE_RES = {width = 640, height = 360}
local screen_center = {x = love.graphics.getWidth() / 2, y = love.graphics.getHeight() / 2}
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
    attack = {'key:z', 'key:j', 'button:y'},
    spin = {'key:x', 'key:k', 'button:b'},
    grab = {'key:c', 'key:l', 'axis:triggerleft+', 'axis:triggerright+'},
    lookLeft = {'key:f', 'axis:rightx-'},
    lookRight = {'key:h', 'axis:rightx+'},
    lookUp = {'key:t', 'axis:righty-'},
    lookDown = {'key:g', 'axis:righty+'},
  },
  pairs = {
    move = {'left', 'right', 'up', 'down'},
    look = {'lookLeft', 'lookRight', 'lookUp', 'lookDown'}
  },
  joystick = love.joystick.getJoysticks()[1],
}

function game_state:enter()
  print(love.graphics.getWidth(), love.graphics.getHeight())
  math.randomseed(os.time())
  love.graphics.setDefaultFilter("nearest", "nearest", 1)
  love.graphics.setLineStyle("rough")

  local tile_world = bump.newWorld(48)
  map = STI("assets/test/maps/test_map.lua", {"bump"})
  map:bump_init(tile_world)
  local entity_layer = map:addCustomLayer("Entities", 3)
  local test_layer = map:addCustomLayer("Test", 3)
  player_spawnx, player_spawny = map.objects[1].x, map.objects[1].y
  print(math.floor(player_spawnx + 0.5), math.floor(player_spawny + 0.5))
  p = Player(math.floor(player_spawnx + 0.5), math.floor(player_spawny + 0.5), entity_collision, tile_world)
  --p = Player(player_spawnx, player_spawny, entity_collision, tile_world)
  --camera = Camera(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)
  --camera = Camera(NATIVE_RES.width/2, NATIVE_RES.height/2)
  --camera.smoother = Camera.smooth.damped(30)
  mycamera = CameraWrapper(player_spawnx, player_spawny, NATIVE_RES, p)
  p.camera = mycamera
  --stalker = Stalker(player_spawnx, player_spawny, NATIVE_RES.width, NATIVE_RES.height)
  --stalker:setFollowStyle('TOPDOWN')
  --stalker:setFollowLerp(0.2)
  --stalker:setFollowLead(2)
  --stalker.draw_deadzone = true
  --stalker:setDeadzone(40, NATIVE_RES.height/2 - 40, NATIVE_RES.width - 80, 80)

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
  --e_guc = et(600, 150, entity_collision, tile_world)
  bouncy = ebt(900, 80, entity_collision, tile_world)
  
  entity_manager:addEntity(bouncy)
  entity_manager:addEntity(e_boy)
  entity_manager:addEntity(e_guy)
  entity_manager:addEntity(e_gut)
  entity_manager:addEntity(e_gur)
  entity_manager:addEntity(e_gue)
  entity_manager:addEntity(e_guw)
  entity_manager:addEntity(e_guq)
  entity_manager:addEntity(e_guz)
  entity_manager:addEntity(e_gux)
  
  --entity_manager:addEntity(e_guc)

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
    --mycamera:lockCamera()
  end
  
  if input:released('attack') then
    p:input_button('release_attack')
    --mycamera:releaseCamera()
  end
  
  if input:pressed('spin') then
    --[[
    test_timer:clear()
    if zoom_tween == nil then 
      zoom_tween = test_timer:tween(1, scaling_factor, {s = 2}, "out-quad") 
    else 
      zoom_tween = test_timer:tween(1, scaling_factor, {s = 1}, "out-quad", function() zoom_tween = nil end)
    end
    ]]
    p:input_button('spin')
  end
  
  if input:released('spin') then 
    p:input_button('release_spin')
  end
  
  if input:pressed('grab') then
    p:input_button('grab')
  end
  
  if input:released('grab') then
    p:input_button('release_grab')
  end
  
  movex, movey = input:get('move')
  
  local lookx, looky = input:get('look')
  
  p:update(dt, movex, movey)
  entity_manager.updateEntities(dt)
  entity_manager:updateRenderOrder()
  --print('bullshit')
  --print(camera:cameraCoords(p.position.x, p.position.y, 0, 0, NATIVE_RES.width, NATIVE_RES.height))
  --print('bringo')
  --print(p.position.x + NATIVE_RES.width, p.position.y + NATIVE_RES.height)
  --  camera:lockPosition(p.position.x, p.position.y)

  --camera:lockWindow(p.position.x, p.position.y, dead_zone_left, dead_zone_right, dead_zone_top, dead_zone_bottom, camera.smoother)
  --camera:lockWindow(p.position.x, p.position.y, NATIVE_RES.width, NATIVE_RES.height, NATIVE_RES.width * 0.25, NATIVE_RES.width * 0.75, NATIVE_RES.height * 0.25, NATIVE_RES.height * 0.75, camera.smoother)
  mycamera:update(dt, lookx, looky)
  --camera:lockWindow(p.position.x, p.position.y, screen_center.x / 2, screen_center.x + (screen_center.x / 2), screen_center.y / 2, screen_center.y + (screen_center.y / 2), camera.smoother)
  --local dx,dy = p.position.x - camera.x, p.position.y - camera.y
  --camera:move(dx, dy)
  --camera:zoomTo(scaling_factor.s)
  --stalker:update(dt)
  --stalker:follow(p.position.x, p.position.y)
  map:update(dt)
  gscreen.update(dt)
  --print('------------')
end

function game_state:draw()
  
  
  gscreen.start()
  --gam:draw(function()
    --stalker:attach()
    --camera:attach(0, 0, love.graphics.getWidth() / gscreen.scale, love.graphics.getHeight() / gscreen.scale, "noclip")
    --camera:attach(0, 0, NATIVE_RES.width, NATIVE_RES.height, "noclip")
    mycamera:attach()
    -- these function the same
    --camera:attach(0, 0, love.graphics.getWidth(), love.graphics.getHeight(), "noclip")
    --camera:attach()
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
    mycamera:detach()
    mycamera:draw()
  --end)
  --stalker:detach()
  --stalker:draw()
  gscreen.stop()
  love.graphics.print("Current FPS: "..tostring(love.timer.getFPS()), 10, 10)
  
end

function game_state:keyreleased()
  --Gamestate.switch(state_manager.menu)
end
  

return game_state
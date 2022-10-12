Camera = require "libs.hump.camera"
Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

CameraWrapper = Object:extend()

function CameraWrapper:new(starting_x, starting_y, native_res, player)
  self.camera = Camera(starting_x, starting_y)
  --self.camera.smoother = Camera.smooth.damped(30)
  -- this saves a copy of the original; this is fine because the native resolution will never change
  self.NATIVE_RES = native_res
  self.player = player
  -- the point that the camera focuses on, relative to the player (in camera coords) 
  self.focus = vector(0,0)
  self.focus_velocity = vector(0,0)
  -- the target's distance to max_target_distance, in camera coords
  self.focus_distance_to_target = vector(0, 0)
  -- the maximum distance from the player the target can be at, in camera coords
  self.focus_target = vector(0,0)
  -- the maximum distance the target can be from the player
  self.MAX_TARGET_DISTANCE = 200
  -- the speed at which the focus moves towards the target when moving at a steady rate
  self.STEADY_FOCUS_SPEED = 200
  self.deadzone = {x1 = self.NATIVE_RES.width/2 - 50, x2 = self.NATIVE_RES.width/2 + 50, y1 = self.NATIVE_RES.height/2 - 25, y2 = self.NATIVE_RES.height/2 + 25}
  
  self.test_target = vector(517, 107)
end

function CameraWrapper:update(dt)
  -- will this cause problems?
  --self.focus= self.player.position
  self:updateTarget(dt)
  --print(self.player.position)
  --self.test_target = self.test_target + vector(0.002, 0)
  --self.camera:lockPosition(self.test_target:unpack())
  --print(self:toWorldCoords(self.NATIVE_RES.width/2,self.NATIVE_RES.height/2))
  --self.camera:lockPosition((self.player.position):unpack())
  --print(self.focus.y)
  self.camera:lockPosition((self.player.position + vector(math.floor(self.focus.x + 0.5), math.floor(self.focus.y + 0.5))):unpack())
  --self.camera:lockWindow(self.focus.x, self.focus.y, self.NATIVE_RES.width, self.NATIVE_RES.height, self.deadzone.x1, self.deadzone.x2, self.deadzone.y1, self.deadzone.y2, self.camera.smoother)
end

function CameraWrapper:updateTarget(dt)
  local player_vel = self.player.player_components.move.velocity:clone()
  if self.player:Current_State_Is("Idle") and self.player.player_components.move.raw_input:len() > 0.001 then
    local _,cpy = self:toCameraCoords(self.player.position:unpack())
    --print(math.floor(cpy + 0.5), cpy, self.player.position.y)
    local vel_range = math.min(player_vel:len() / 400, 1)
    --print(vel_range)
    self.focus_target = player_vel:normalized() * (self.MAX_TARGET_DISTANCE * vel_range)
    --print(self.focus_target:len())

    -- this turns the circled as described by focus_target vector into an ellipse, using the ellipse equation: x^2/a^2 + y^2/b^2 = 1
    -- the magic number 0.5625 is 9/16; maybe I should change this for different aspect ratios
    local y_sign = utilities.sign(self.focus_target.y)
    local new_y = math.sqrt((self.focus_target:len()^2 - self.focus_target.x^2) * (0.5625^2)) * y_sign
    --print(new_y)
    self.focus_target.y = new_y
    self.focus_target = vector(math.floor(self.focus_target.x + 0.5), math.floor(self.focus_target.y + 0.5))
    --print(self.focus_target)
    
    --self:moveFocus('x', dt)
    --self:moveFocus('y', dt)
    self:moveSilly()
    self.focus = self.focus + (self.focus_velocity * dt)
  end
  
  local distance_to_line = (self.focus - (self.focus:projectOn(self.focus_target)))
  if distance_to_line:len() < 1 then self.focus = self.focus - distance_to_line end
  
  self.focus_distance_to_target = self.focus - self.focus_target
  if self.focus_distance_to_target:len() < 1 then self.focus = self.focus_target --[[print(self.focus_target)]] end
  
  --print(self.focus)
end

-- four different methods for moving the focus point each frame:
-- moveFocus deals with one axis of movement at a time, a more hacky solution but probably closest to my original intent - still scared of bugs though
-- moveFunny is a simpler solution using vectors rather than dealing axes - simple but not super polished
-- moveGoofy is a more complex solution using vectors - little bit nicer looking than funny, but has some quirks
-- moveSilly is a more refined version of moveGoofy

function CameraWrapper:moveFocus(axis, dt)
  local focus_sign = math.abs(self.focus[axis]) > 1.001 and utilities.sign(self.focus[axis]) or 0
  local target_sign = math.abs(self.focus_target[axis]) > 1.001 and utilities.sign(self.focus_target[axis]) or 0
  local new_velocity = self.focus_velocity

  if focus_sign ~= target_sign then
    -- the camera rushes to catch up to the player when they start moving in a different direction
    -- speed of velocity is based on how far the focus is from the target
    new_velocity[axis] = math.min(math.abs(self.focus[axis]) / self.MAX_TARGET_DISTANCE, 1) * 500 + 50
    -- direction of velocity is based on 
    local focus_dir = utilities.sign(target_sign - focus_sign)
    new_velocity[axis] = new_velocity[axis] * focus_dir
  else
    -- the camera gradually moves in the direction that the player is moving in
    local focus_dir = utilities.sign(self.focus[axis] - self.focus_target[axis])
    new_velocity[axis] = 50 * -focus_dir
  end
  self.focus_velocity = new_velocity
end

function CameraWrapper:moveFunny(dt)
  local new_velocity = -self.focus_distance_to_target:normalized() * 200
  -- if the focus is a certain distance away from the target..
  if self.focus_distance_to_target:len() > self.focus_target:len() then
    -- ...then it will move directly towards the target, the farther it is away, the faster.
    local speed = math.min(self.focus:len() / self.MAX_TARGET_DISTANCE, 1) * 500 + 200
    new_velocity = -self.focus_distance_to_target:normalized() * speed
  end
  self.focus_velocity = new_velocity
 end 
 
 function CameraWrapper:moveGoofy(dt)
  -- two vectors: one parallel to the target vector, and one perpendicular; they are combined to get the movement vector at the end.
  local parallel = self.focus_target:normalized() * 50
  -- if parallel vector is beyond the target, it is flipped so it points in the direction of the target no matter what
  if self.focus:len() > self.focus_target:len() then parallel = -parallel end
  -- perpendistance is the distance between the focus and the target line; the farther away the focus is from the target line, the faster it will move toward it, perpendicularly. 
  --local perpendistance = -(self.focus - (self.focus:projectOn(self.focus_target)))
  -- the above value represents the distance as a straight line: the below is slanted. either work, though.
  local perpendistance = -(self.focus - (self.focus_target:normalized() * self.focus:len()))
  -- the farther away the focus is from the target line, the faster it will move toward it, perpendicularly. 
  local per_speed = math.min(perpendistance:len() / self.MAX_TARGET_DISTANCE, 1) * 800 + 40
  local perpendicular = perpendistance:normalized() * per_speed
  
  -- the movement vector is a mix of parallel and perpendicular vectors.
  local mixed_vector = parallel - (parallel - perpendicular)/2
  local new_velocity = mixed_vector
  -- if the focus is a certain distance away from the target..
  if self.focus_distance_to_target:len() > self.focus_target:len() then
    -- ...then it will move directly towards the target, the farther it is away, the faster.
    local speed = math.min((self.focus_distance_to_target:len() - self.focus_target:len()) / self.MAX_TARGET_DISTANCE*2, 1) * 500 + 200
    new_velocity = -self.focus_distance_to_target:normalized() * speed
  end
  self.focus_velocity = new_velocity
 end 
 
  function CameraWrapper:moveSilly(dt)
  -- two vectors: one parallel to the target vector, and one perpendicular; they are combined to get the movement vector at the end.
  local parallel = self.focus_target:normalized() * 50
  -- if parallel vector is beyond the target, it is flipped so it points in the direction of the target no matter what
  if self.focus:projectOn(self.focus_target):len() > self.focus_target:len() then parallel = -parallel end
  if (self.focus_target - self.focus:projectOn(self.focus_target)):len() <  1 then parallel = self.focus_target:normalized() * 0 end
  
  --if self.focus_target - self.focus:projectOn(self.focus_target)
  -- perpendistance is the distance between the focus and the target line; the farther away the focus is from the target line, the faster it will move toward it, perpendicularly. 
  local perpendistance = -(self.focus - (self.focus:projectOn(self.focus_target)))
  -- the above value represents the distance as a straight line: the below is slanted. either work, though.
  --local perpendistance = -(self.focus - (self.focus_target:normalized() * self.focus:len()))
  -- the farther away the focus is from the target line, the faster it will move toward it, perpendicularly. 
  local per_speed = math.min(perpendistance:len() / self.MAX_TARGET_DISTANCE, 1) * 500 + 10
  local perpendicular = perpendistance:normalized() * per_speed
  
  -- if parallel needs to catch up, it will go faster the further it is away
  -- self.focus_target * projected finds the dot product of the target and the projected vector. If it is negative, then the projected vector is pointed in the opposite direction of the target, meaning it has to catch up.
  if self.focus_target * (self.focus:projectOn(self.focus_target)) < 0 then
    -- finds speed of parallel axis based on how far the projected vector is from being pointed in the right direction
    local par_speed = math.min(self.focus:projectOn(self.focus_target):len() / self.MAX_TARGET_DISTANCE, 1) * 700 + 50
    -- sets the new parallel axis
    parallel = self.focus_target:normalized() * par_speed
  end
  -- the movement vector is a mix of parallel and perpendicular vectors.
  --local mixed_vector = parallel - (parallel - perpendicular)/2
  --if mixed_vector:len() < 50 then mixed_vector = mixed_vector:normalizeInplace() * 50 end
  local mixed_vector = parallel + perpendicular
  self.focus_velocity = mixed_vector
  
  local distance_to_line = (self.focus - (self.focus:projectOn(self.focus_target)))
  --print(distance_to_line:len())
  if distance_to_line:len() < 1 then self.focus_velocity = parallel end
  --print(self.focus_velocity:len())
 end 

function CameraWrapper:attach()
  self.camera:attach(0, 0, self.NATIVE_RES.width, self.NATIVE_RES.height, "noclip")
end

function CameraWrapper:detach()
  self.camera:detach()
end

function CameraWrapper:toCameraCoords(x, y)
  return self.camera:cameraCoords(x, y, 0, 0, self.NATIVE_RES.width, self.NATIVE_RES.height)
end

function CameraWrapper:toWorldCoords(x, y)
  return self.camera:worldCoords(x, y, 0, 0, self.NATIVE_RES.width, self.NATIVE_RES.height)
end

function CameraWrapper:draw()
  love.graphics.setColor(51/255, 255/255, 230/255, 1)
  
  -- draws focus
  local tarx, tary = self:toCameraCoords((self.player.position + self.focus):unpack())
  love.graphics.points(tarx, tary)
  love.graphics.circle('line', tarx, tary, 5)
  
  -- draws line from player to focus
  local px, py = self:toCameraCoords(self.player.position:unpack())
  love.graphics.line(px, py, tarx, tary)
  
  love.graphics.setColor(255/255, 208/255, 51/255, 1)

  -- draws line from focus to target
  --love.graphics.line(tarx, tary, tarx-self.focus_distance_to_target.x, tary-self.focus_distance_to_target.y)
  
  -- draws target
  local mtarx, mtary = self:toCameraCoords((self.player.position + self.focus_target):unpack())
  love.graphics.points(mtarx, mtary)
  love.graphics.circle('line', mtarx, mtary, 5)
  --love.graphics.circle('line', mtarx, mtary, self.focus_target:len())
  
  -- draws line from player to target
  love.graphics.line(px,py,mtarx,mtary)
  love.graphics.circle('line', px,py,self.MAX_TARGET_DISTANCE)
  
  love.graphics.setColor(0, 1, 0, 1)
    
  -- projected
  local prox, proy = self.focus:projectOn(self.focus_target):unpack()
  love.graphics.line(px, py, px+prox, py+proy)
  
  love.graphics.setColor(0.5, 0.5, 0.9, 1)
  --difference between projected and target
  local proprox, proproy = (self.focus_target - self.focus:projectOn(self.focus_target)):unpack()
  --love.graphics.line(px+prox, py+proy, px+prox+proprox, py+proy+proproy)
  
  --local beefx, beefy = self.focus_target:projectOn(vector(1,0)):unpack()
  --local beefx, beefy = (vector(1,0) * self.focus_target.x):unpack()
  --love.graphics.line(px, py, px+beefx, py+beefy)
  
  love.graphics.setColor(1, 0, 1, 1)
  
  -- distance to projected
  --local hix, hiy = (self.focus - (self.focus:projectOn(self.focus_target))):unpack()
  --love.graphics.line(tarx, tary, tarx-hix, tary-hiy)

  -- this draws the goofy focus movement technique
  local parallel = (self.focus_target:normalized() * 50)
  if self.focus:projectOn(self.focus_target):len() > self.focus_target:len() then parallel = -parallel end
  if (self.focus_target - self.focus:projectOn(self.focus_target)):len() < 1 then parallel = self.focus_target:normalized() * 0 end

  local perpendistance = -(self.focus - (self.focus:projectOn(self.focus_target)))
  --local perpendistance = -(self.focus - (self.focus_target:normalized() * self.focus:len()))
  local per_speed = math.min(perpendistance:len() / self.MAX_TARGET_DISTANCE, 1) * 500 + 5
  local perpendicular = perpendistance:normalized() * per_speed
    
  if self.focus_target * (self.focus:projectOn(self.focus_target)) < 0 then
    local par_speed = math.min(self.focus:projectOn(self.focus_target):len() / self.MAX_TARGET_DISTANCE, 1) * 500 + 50
    parallel = self.focus_target:normalized() * par_speed
  end
  --local mixed_vector = parallel - (parallel - perpendicular)/2
  --if mixed_vector:len() < 50 then mixed_vector = mixed_vector:normalizeInplace() * 50 end
  local mixed_vector = parallel + perpendicular
  
  local distance_to_line = (self.focus - (self.focus:projectOn(self.focus_target)))
  --print(distance_to_line:len())
  if distance_to_line:len() < 1 then mixed_vector = parallel end
    
  --love.graphics.line(tarx, tary, tarx + perpendistance.x, tary + perpendistance.y)
  --love.graphics.setColor(1, 0.5, 0, 1)
  love.graphics.line(tarx, tary, tarx + perpendicular.x, tary + perpendicular.y)
  love.graphics.line(tarx, tary, tarx + parallel.x, tary + parallel.y)
    love.graphics.line(tarx + perpendicular.x, tary + perpendicular.y, tarx + perpendicular.x + parallel.x, tary + perpendicular.y + parallel.y)
  love.graphics.line(tarx + parallel.x, tary + parallel.y, tarx + parallel.x + perpendicular.x, tary + parallel.y + perpendicular.y)
  love.graphics.setColor(1, 0, 0, 1)
  love.graphics.line(tarx,tary,tarx+mixed_vector.x,tary+mixed_vector.y)

  love.graphics.setColor(51/255, 255/255, 230/255, 1)
  --love.graphics.points(self.NATIVE_RES.width/2, self.NATIVE_RES.height/2)
  love.graphics.setColor(1, 1, 1, 1)
end

return CameraWrapper
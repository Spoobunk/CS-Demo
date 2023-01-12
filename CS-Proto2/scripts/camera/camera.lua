Camera = require "libs.hump.camera"
Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

CameraWrapper = Object:extend()

function CameraWrapper:new(starting_x, starting_y, native_res, player)
  self.camera = Camera(starting_x, starting_y)
  self.camera.smoother = Camera.smooth.damped(30)
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
  self.MAX_TARGET_DISTANCE = 60
  -- the speed at which the focus moves towards the target when moving at a steady rate
  -- not currently used
  self.STEADY_FOCUS_SPEED = 20
  -- how fast the focus should speed through the first bit of distance towards the target
  -- not currently used
  self.EXTRA_LOOKAHEAD = 60
  -- the distance the player can see ahead when they are aiming a throw
  self.AIM_LOOKAHEAD_DISTANCE = 90
  
  -- the speed the focus should move at when distance from the target is 0
  self.BASE_LOOKAHEAD_SPEED = 13
  -- the distance that the player should be able to see when looking with the right stick
  self.LOOK_DISTANCE = 150
  
  self.origin = self.player.ground_pos - vector(0, self.player.base_height)
  self.origin_target = self.origin:clone()
  self.locked_x = nil
  self.locked_y = nil
  self.origin_locked = true
  self.last_locked_x = nil
  self.last_locked_y = nil
  self.origin_distance_to_target = vector(0,0)
  
  -- vector representing the displacement of the origin when looking with the right stick
  self.origin_look_distance = vector(0,0)
  
  self.current_bounds = {x1 = -1200, x2 = 1500, y1 = -1200, y2 = 1500}
  self.deadzone = {x1 = self.NATIVE_RES.width/2 - 15, x2 = self.NATIVE_RES.width/2 + 15, y1 = self.NATIVE_RES.height/2 - 10, y2 = self.NATIVE_RES.height/2 + 10}
  
  self.current_shudder = nil
end

function CameraWrapper:update(dt, lookx, looky)
  -- will this cause problems?
  --self.focus= self.player.position
  self:updateOrigin(dt, vector(lookx, looky))
  self:updateTarget(dt, vector(lookx, looky))
  --print(self.player.position)
  --self.test_target = self.test_target + vector(0.002, 0)
  --self.camera:lockPosition(self.test_target:unpack())
  --print(self:toWorldCoords(self.NATIVE_RES.width/2,self.NATIVE_RES.height/2))
  --self.camera:lockPosition((self.player.position):unpack())
  --self.camera:lockPosition((self.player.position + self.focus):unpack())
  --self.origin = self.player.position:clone()
  local new_camera_pos = self.origin + self.focus
  if self.current_shudder then 
    self.current_shudder:update(dt) 
    --self.camera:lockPosition(((self.origin + self.current_shudder:amplitude()) + self.focus):unpack())
    new_camera_pos = new_camera_pos + self.current_shudder:amplitude()
    if not self.current_shudder.isShuddering then self.current_shudder = nil end
  end
  self.camera:lockPosition(new_camera_pos:unpack())
  --self.camera:lockWindow(new_camera_pos.x, new_camera_pos.y, self.NATIVE_RES.width, self.NATIVE_RES.height, self.deadzone.x1, self.deadzone.x2, self.deadzone.y1, self.deadzone.y2, self.camera.smoother)
end

function CameraWrapper:updateTarget(dt, look)
  -- look argument is an axis tied to the right stick. leaving here in case I ever want to try to add that look feature
  --if self.player.current_state.moveCamera == 'always' or (self.player.current_state.moveCamera == 'with_input' and self.player.player_components.move.raw_input:len() > 0.001 and self.player.current_movestep:len() > 0.1) then  
  if self.player.current_state.moveCamera == 'always' or (self.player.current_state.moveCamera == 'with_movement' and self.player.current_movestep:len() > 0.5) then  
    if self.player.current_state.moveCameraTarget then 
      local player_vel = self.player.player_components.move.velocity:clone()
      --player_vel = vector(math.floor((player_vel.x * 10) + 0.5) / 10, math.floor((player_vel.y * 10) + 0.5) / 10)
      local vel_range = math.min(player_vel:len() / 400, 1)
      --vel_range = math.floor((vel_range * 100) + 0.5) / 100
      
      -- right now, using analog control and trying to move with a velocity under 400 (the max range for how far the target is) causes the target to jitter a lot. I'm pretty sure that this is because of the random variation in the player's velocity because of how dt is factored into it; but I don't have a solution right now. So, I'm gonna leave it for now since it isn't THAT important. I might post on the LOVE2D forums for ideas on how to fix this, cause I'm really not sure of the best way to deal with dt at all.
      
      -- this decreases the amount of random variation that is present in the player's velocity, which causes the camera to jitter when at max distance. 
      -- the camera can still jitter when moving at certain angles, but it doesn't happen as often.
      local vel_direction = vector(math.floor((player_vel:normalized().x * 100) + 0.5) / 100, math.floor((player_vel:normalized().y * 100) + 0.5) / 100)
      local new_target = self:ellipsify(vel_direction * (self.MAX_TARGET_DISTANCE * vel_range))
      self:setTarget(new_target)
    end
    --self.focus_target = vector(math.floor(self.focus_target.x + 0.5), math.floor(self.focus_target.y + 0.5))
    if type(self.locked_x) == 'number' then self.focus_target.x = 0 end
    if type(self.locked_y) == 'number' then self.focus_target.y = 0 end
    
    local distance_to_line = (self.focus - (self.focus:projectOn(self.focus_target)))
    if distance_to_line:len() < 1 then self.focus = self.focus - distance_to_line end
    
    self.focus_distance_to_target = self.focus - self.focus_target
    if self.focus_distance_to_target:len() < 1 then self.focus = self.focus_target end

    if self.player.current_state.moveCameraFocusMethod == 'normal' then self:moveNatural() 
    elseif self.player.current_state.moveCameraFocusMethod == 'fast' then self:moveFast() 
    -- not currently being used by any player state
    elseif self.player.current_state.moveCameraFocusMethod == 'direct' then self:moveDirect() end
      
    --self.focus = self.focus + (self.focus_velocity * dt)
    self:setFocus(self.focus + (self.focus_velocity * dt))
  end
  
end

-- I just realized that this whole origin thing would have been so much easier if I just thought to make the origin vector relative to the player, rather than in world coordinates. oh well, it works alright as it is
function CameraWrapper:updateOrigin(dt, look_vector)
  if (not (type(self.locked_x) == 'number' or type(self.locked_x) == 'nil')) or (not (type(self.locked_y) == 'number' or type(self.locked_y) == 'nil')) then
    error('A invalid value was entered for camera lock coordinates.')
  end
  --if look_vector:len() > 0.001 then self:lockCamera((self.player.position:clone() + (look_vector:normalized() * self.LOOK_DISTANCE)):unpack()) end

  -- this checks to see if the player has entered or exited a camera lock area, resulting in a new origin target.
  if self.locked_x ~= self.last_locked_x or self.locked_y ~= self.last_locked_y then 
    -- print('new target: ' .. (self.locked_x or 'player x') .. ', ' .. (self.locked_y or 'player y'))
    -- if there is a new origin target, the origin lock is disabled, so the origin can move towards the origin target
    self.origin_locked = false 
    self.origin_target = vector(self.locked_x or self:findPlayersOrigin(look_vector, dt).x, self.locked_y or self:findPlayersOrigin(look_vector, dt).y)
    -- the distance to the new origin target is found only once, the first time the new target appears.
    self.origin_distance_to_target = self.origin - self.origin_target
  end
  
  self.origin_target = vector(self.locked_x or self:findPlayersOrigin(look_vector, dt).x, self.locked_y or self:findPlayersOrigin(look_vector, dt).y)
  -- if the origin lock is enabled, then the origin is always set to the target. But if it is disabled..
  if self.origin_locked then self:setOrigin(self.origin_target) else 
    
    -- with this process, instead of the origin moving towards the target, the distance FROM the target to the origin is reduced. I did this so that with a moving target, such as the player, the origin can always catch up to the target, no matter how fast the target is moving.
    local speed = math.min(self.origin_distance_to_target:len() / 200, 1) * 900 + 10
    self.origin_distance_to_target = self.origin_distance_to_target:normalized() * (self.origin_distance_to_target:len() - (speed*dt))
    
    if self.origin_distance_to_target:len() < 1 then 
      self:setOrigin(self.origin_target) 
      self.origin_locked = true
      --print('locked')
    end
  
    self:setOrigin(self.origin_target + self.origin_distance_to_target)
  end
  -- we save the locked variables from this frame so that we can check to see if anything has changed next frame.
  self.last_locked_x, self.last_locked_y = self.locked_x, self.locked_y
end

-- this function finds the origin that should be used by the camera when following the player. this is normally just the player's position, but it changes if the player is using the right stick to look around
function CameraWrapper:findPlayersOrigin(look_vector, dt)
  local origin_look_distance_target = vector(0,0)

  if look_vector:len() > 0.001 and self.player:Get_Current_State() ~= 'throwing' then
    origin_look_distance_target = self:ellipsify(look_vector:normalized() * self.LOOK_DISTANCE)
  end
  local distance_to_target = self.origin_look_distance - origin_look_distance_target
  if distance_to_target:len() < 2 then 
    self.origin_look_distance = origin_look_distance_target 
    return self.player.ground_pos - vector(0, self.player.base_height) + self.origin_look_distance
  end
  local speed = math.min(distance_to_target:len() / (self.LOOK_DISTANCE*2), 1) * 600 + 20
  local new_velocity = -distance_to_target:normalized() * speed
  self.origin_look_distance = self.origin_look_distance + (new_velocity * dt)
  return self.player.ground_pos - vector(0, self.player.base_height) + self.origin_look_distance
end
  

function CameraWrapper:setFocus(new_value)
  local is_out = self:checkCameraBounds(self.origin + new_value)
  if is_out.x == -1 then 
    self.focus.x = (self.current_bounds.x1 + (self.NATIVE_RES.width/2)) - self.origin.x
  elseif is_out.x == 1 then 
    self.focus.x = (self.current_bounds.x2 - (self.NATIVE_RES.width/2)) - self.origin.x
  else
    self.focus.x = new_value.x
  end

  if is_out.y == -1 then 
    self.focus.y = (self.current_bounds.y1 + (self.NATIVE_RES.height/2)) - self.origin.y 
  elseif is_out.y == 1 then
    self.focus.y = (self.current_bounds.y2 - (self.NATIVE_RES.height/2)) - self.origin.y 
  else
    self.focus.y = new_value.y
  end
end

function CameraWrapper:setTarget(new_value)
  local after_origin_check = vector(0,0)
  if self.origin.x == (self.player.ground_pos - vector(0, self.player.base_height)).x then
    after_origin_check.x = new_value.x
  end
  if self.origin.y == (self.player.ground_pos - vector(0, self.player.base_height)).y then
    after_origin_check.y = new_value.y
  end
  self.focus_target = after_origin_check
end

function CameraWrapper:setOrigin(new_value)
  local is_out = self:checkCameraBounds(new_value)
  if is_out.x == -1 then 
    self.origin.x = self.current_bounds.x1 + (self.NATIVE_RES.width/2)
  elseif is_out.x == 1 then 
    self.origin.x = self.current_bounds.x2 - (self.NATIVE_RES.width/2)
  else
    self.origin.x = new_value.x
  end

  if is_out.y == -1 then 
    self.origin.y = self.current_bounds.y1 + (self.NATIVE_RES.height/2)
  elseif is_out.y == 1 then
    self.origin.y = self.current_bounds.y2 - (self.NATIVE_RES.height/2)
  else
    self.origin.y = new_value.y
  end
end

function CameraWrapper:checkCameraBounds(camera_pos)
  -- this vector tracks if camera_pos is out of bounds on the x and y axes, and in what direction (1 for down or right, -1 for up or left, 0 for within bounds)
  local is_out = vector(0,0)
  if camera_pos.x - (self.NATIVE_RES.width/2) < self.current_bounds.x1 then is_out.x = -1 end
  if camera_pos.x + (self.NATIVE_RES.width/2) > self.current_bounds.x2 then is_out.x = 1 end
  if camera_pos.y - (self.NATIVE_RES.height/2) < self.current_bounds.y1 then is_out.y = -1 end
  if camera_pos.y + (self.NATIVE_RES.height/2) > self.current_bounds.y2 then is_out.y = 1 end
  return is_out
end

function CameraWrapper:ellipsify(target)
  -- this turns the circle as described by focus_target vector into an ellipse, using the ellipse equation: x^2/a^2 + y^2/b^2 = 1
  -- the magic number 0.5625 is 9/16; maybe I should change this for different aspect ratios
  --[[local new_target = target:clone()
  local y_sign = utilities.sign(new_target.y)
  local new_y = math.sqrt((new_target:len()^2 - new_target.x^2) * (0.8^2)) * y_sign
  new_target.y = new_y
  return new_target]]
  return utilities.ellipsify(target, 0.8)
end

-- remember to use the nil keyword if you want to skip an argument
function CameraWrapper:lockCamera(x, y)
  self.locked_x = x or self.locked_x
  self.locked_y = y or self.locked_y
end

function CameraWrapper:releaseCamera()
  self.locked_x = nil
  self.locked_y = nil
end

-- four different methods for moving the focus point each frame:
-- moveFocus deals with one axis of movement at a time, a more hacky solution but probably closest to my original intent - still scared of bugs though
-- moveFunny is a simpler solution using vectors rather than dealing with axes - simple but not super polished
-- moveGoofy is a more complex solution using vectors - little bit nicer looking than funny, but has some quirks
-- moveSilly is a more refined version of moveGoofy
-- moveFast, used when aiming a throw
-- moveDirect, used when quickly recentering the player in the screen after getting hit

function CameraWrapper:moveFocus(axis, dt)
  local focus_sign = math.abs(self.focus[axis]) > 1.001 and utilities.sign(self.focus[axis]) or 0
  local target_sign = math.abs(self.focus_target[axis]) > 1.001 and utilities.sign(self.focus_target[axis]) or 0
  local new_velocity = self.focus_velocity

  if focus_sign ~= target_sign then
    -- the camera rushes to catch up to the player when they start moving in a different direction
    -- speed of velocity is based on how far the focus is from the target
    new_velocity[axis] = math.min(math.abs(self.focus[axis]) / self.MAX_TARGET_DISTANCE, 1) * 500 + self.STEADY_FOCUS_SPEED
    -- direction of velocity is based on 
    local focus_dir = utilities.sign(target_sign - focus_sign)
    new_velocity[axis] = new_velocity[axis] * focus_dir
  else
    -- the camera gradually moves in the direction that the player is moving in
    local focus_dir = utilities.sign(self.focus[axis] - self.focus_target[axis])
    new_velocity[axis] = self.STEADY_FOCUS_SPEED * -focus_dir
  end
  self.focus_velocity = new_velocity
end
 
 
function CameraWrapper:moveSilly(dt)
  local projected = self.focus_target == vector(0,0) and vector(0,0) or self.focus:projectOn(self.focus_target)
  -- paradistance is the distance between the focus and the target along the parallel axis
  local paradistance = self.focus_target - projected
  -- two vectors: one parallel to the target vector, and one perpendicular; they are combined to get the movement vector at the end.
  --local parallel = self.focus_target:normalized() * self.STEADY_FOCUS_SPEED
  --the line above makes it so parallel movement speed is constant
  --the line below makes the parallel movement speed a bit faster when just starting out, then slowing down into the steady, constant speed. It's just so the player always can see at least a little bit in front of themselves.
  local parallel = self.focus_target:normalized() * (math.min(math.max(paradistance:len() - (self.focus_target:len()*0.6), 0) / (self.focus_target:len()*0.4), 1) * self.EXTRA_LOOKAHEAD + self.STEADY_FOCUS_SPEED)
  -- if parallel vector is beyond the target, it is flipped so it points in the direction of the target no matter what
  if self.focus:projectOn(self.focus_target):len() > self.focus_target:len() then parallel = -parallel end
  -- if the focus is already in line with the target perpendicularly, the parallel vector will be set to 0.
  if (self.focus_target - projected):len() < 1 then parallel = self.focus_target:normalized() * 0 end
  
  --if self.focus_target - self.focus:projectOn(self.focus_target)
  -- perpendistance is the distance between the focus and the target line; the farther away the focus is from the target line, the faster it will move toward it, perpendicularly. 
  local perpendistance = -(self.focus - projected)
  -- the above value represents the distance as a straight line: the below is slanted. either work, though.
  --local perpendistance = -(self.focus - (self.focus_target:normalized() * self.focus:len()))
  -- the farther away the focus is from the target line, the faster it will move toward it, perpendicularly. 
  local per_speed = math.min(perpendistance:len() / self.MAX_TARGET_DISTANCE, 1) * 300 + 5
  local perpendicular = perpendistance:normalized() * per_speed
  
  -- if parallel needs to catch up, it will go faster the further it is away
  -- self.focus_target * projected finds the dot product of the target and the projected vector. If it is negative, then the projected vector is pointed in the opposite direction of the target, meaning it has to catch up.
  if self.focus_target * projected < 0 then
    -- finds speed of parallel axis based on how far the projected vector is from being pointed in the right direction
    local par_speed = math.min(projected:len() / self.MAX_TARGET_DISTANCE, 1) * 230 + (self.STEADY_FOCUS_SPEED + self.EXTRA_LOOKAHEAD)
    -- sets the new parallel axis
    parallel = self.focus_target:normalized() * par_speed
  end
  -- the movement vector is a mix of parallel and perpendicular vectors.
  --local mixed_vector = parallel - (parallel - perpendicular)/2
  --if mixed_vector:len() < self.STEADY_FOCUS_SPEED then mixed_vector = mixed_vector:normalizeInplace() * self.STEADY_FOCUS_SPEED end
  local mixed_vector = parallel + perpendicular
  self.focus_velocity = mixed_vector
  
  local distance_to_line = (self.focus - projected)
  if distance_to_line:len() < 1 then self.focus_velocity = parallel end
 end 
 
 function CameraWrapper:moveNatural(dt)
  local projected = self.focus_target == vector(0,0) and vector(0,0) or self.focus:projectOn(self.focus_target)
  -- paradistance is the distance between the focus and the target along the parallel axis
  local paradistance = self.focus_target - projected
  -- two vectors: one parallel to the target vector, and one perpendicular; they are combined to get the movement vector at the end.
  --local parallel = self.focus_target:normalized() * self.STEADY_FOCUS_SPEED
  --the line above makes it so parallel movement speed is constant
  --the line below makes the parallel movement speed a bit faster when just starting out, then slowing down into the steady, constant speed. It's just so the player always can see at least a little bit in front of themselves.
  --local parallel = self.focus_target:normalized() * (math.min(math.max(paradistance:len() - (self.focus_target:len()*0.6), 0) / (self.focus_target:len()*0.4), 1) * self.EXTRA_LOOKAHEAD + self.STEADY_FOCUS_SPEED)
  local par_speed = math.min(paradistance:len() / self.focus_target:len(), 1) * 30 + self.BASE_LOOKAHEAD_SPEED
  local parallel = paradistance:normalized() * par_speed
  -- if the focus is already in line with the target perpendicularly, the parallel vector will be set to 0.
  if (self.focus_target - projected):len() < 1 then parallel = paradistance:normalized() * 0 end
  
  --if self.focus_target - self.focus:projectOn(self.focus_target)
  -- perpendistance is the distance between the focus and the target line; the farther away the focus is from the target line, the faster it will move toward it, perpendicularly. 
  local perpendistance = -(self.focus - projected)
  -- the above value represents the distance as a straight line: the below is slanted. either work, though.
  --local perpendistance = -(self.focus - (self.focus_target:normalized() * self.focus:len()))
  -- the farther away the focus is from the target line, the faster it will move toward it, perpendicularly. 
  local per_speed = math.min(perpendistance:len() / self.MAX_TARGET_DISTANCE, 1) * 150 + 5
  local perpendicular = perpendistance:normalized() * per_speed
  
  -- if parallel needs to catch up, it will go faster the further it is away
  -- self.focus_target * projected finds the dot product of the target and the projected vector. If it is negative, then the projected vector is pointed in the opposite direction of the target, meaning it has to catch up.
  if self.focus_target * projected < 0 then
    -- finds speed of parallel axis based on how far the projected vector is from being pointed in the right direction
    local par_speed = math.min(projected:len() / self.MAX_TARGET_DISTANCE, 1) * 200 + self.BASE_LOOKAHEAD_SPEED
    -- sets the new parallel axis
    parallel = self.focus_target:normalized() * par_speed
  end
  -- the movement vector is a mix of parallel and perpendicular vectors.
  --local mixed_vector = parallel - (parallel - perpendicular)/2
  --if mixed_vector:len() < self.STEADY_FOCUS_SPEED then mixed_vector = mixed_vector:normalizeInplace() * self.STEADY_FOCUS_SPEED end
  local mixed_vector = parallel + perpendicular
  self.focus_velocity = mixed_vector
  
  local distance_to_line = (self.focus - projected)
  if distance_to_line:len() < 1 then self.focus_velocity = parallel end
 end 
 
 function CameraWrapper:moveFast(dt)
  local projected = self.focus_target == vector(0,0) and vector(0,0) or self.focus:projectOn(self.focus_target)
  -- paradistance is the distance between the focus and the target along the parallel axis
  local paradistance = self.focus_target - projected
  local par_speed = math.min(paradistance:len() / (self.focus_target:len()*2), 1) * 800 + 100
  -- stuff in this if statement alters the speed of the focus once it is pointing in the same direction as the target (i.e. once it is 'in front' of the player instead of 'behind'). I found that slowing it down when in front of the player makes aiming less disorienting, but it takes longer to see the full distance in front of the player. Speeding it up lets you see more stuff faster, but is more abrupt and probably not worth it. I also used the same technique that I used in moveSilly(), where once the focus is in front of the player, it travels quickly for some distance, then slows down into a constant speed. This allows the player to see some distance in front of them quickly enough, but slows it down so as not to be too disorienting. None of these options are bad, so I haven't decided which one to use yet.
  if paradistance:len() < self.focus_target:len() then 
    par_speed = math.min(paradistance:len() / (self.focus_target:len()), 1) * 350 + 50
    --par_speed = math.min(math.max(paradistance:len() - (self.focus_target:len()*0.4), 0) / (self.focus_target:len()*0.6), 1) * 300 + 200
    --print(par_speed)
  end
  -- the paradistance vector always points towards the target along the parallel axis
  local parallel = paradistance:normalized() * par_speed
  -- if the focus is already in line with the target perpendicularly, the parallel vector will be set to 0.
  if (self.focus_target - projected):len() < 1 then parallel = self.focus_target:normalized() * 0 end
  
  -- perpendistance is the distance between the focus and the target line; the farther away the focus is from the target line, the faster it will move toward it, perpendicularly. 
  local perpendistance = -(self.focus - projected)
  -- the farther away the focus is from the target line, the faster it will move toward it, perpendicularly. 
  local per_speed = math.min(perpendistance:len() / self.AIM_LOOKAHEAD_DISTANCE, 1) * 350 + 10
  local perpendicular = perpendistance:normalized() * per_speed
  
  local mixed_vector = parallel + perpendicular
  self.focus_velocity = mixed_vector
  
  local distance_to_line = (self.focus - projected)
  if distance_to_line:len() < 1 then self.focus_velocity = parallel end
 end 
 
function CameraWrapper:moveDirect()
  local speed = math.min(self.focus_distance_to_target:len() / 50, 1) * 800 + 5
  local new_velocity = -self.focus_distance_to_target:normalized() * speed
  if self.focus_distance_to_target:len() < 5 then new_velocity = vector(0,0) self.focus = self.focus_target end
  self.focus_velocity = new_velocity
end

-- just testing something
function CameraWrapper:moveDirectAiming()
  local speed = math.min(self.focus_distance_to_target:len() / (self.focus_target:len()*2), 1) * 900 + 100
  local new_velocity = -self.focus_distance_to_target:normalized() * speed
  self.focus_velocity = new_velocity
end
 
 -- shakes the screen with supplied duration, frequency and amplitude
function CameraWrapper:screenShake(duration, frequency, amplitude_max)
   self.current_shudder = utilities:newShudder(duration, frequency, amplitude_max)
   --self.current_shudder = utilities:newShudder(0.5, 40, 15)
end

-- cancels any screen shake that could be ocurring
function CameraWrapper:cancelScreenShake()
  self.current_shudder = nil
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

function CameraWrapper:drawCameraBounds()
  love.graphics.rectangle('line', self.current_bounds.x1, self.current_bounds.y1, self.current_bounds.x2 - self.current_bounds.x1, self.current_bounds.y2 - self.current_bounds.y1)
  love.graphics.rectangle('line', self.current_bounds.x1 + (self.NATIVE_RES.width/2), self.current_bounds.y1 + (self.NATIVE_RES.height/2), (self.current_bounds.x2 - self.current_bounds.x1) - (self.NATIVE_RES.width/2), (self.current_bounds.y2 - self.current_bounds.y1) - (self.NATIVE_RES.height/2))
end

function CameraWrapper:draw()
  
  love.graphics.setColor(51/255, 255/255, 230/255, 1)
  
  -- draws focus
  local tarx, tary = self:toCameraCoords((self.origin + self.focus):unpack())
  love.graphics.points(tarx, tary)
  love.graphics.circle('line', tarx, tary, 5)
  
  -- draws line from player to focus
  local px, py = self:toCameraCoords(self.origin:unpack())
  --love.graphics.line(px, py, tarx, tary)
  
  love.graphics.setColor(255/255, 208/255, 51/255, 1)

  -- draws line from focus to target
  --love.graphics.line(tarx, tary, tarx-self.focus_distance_to_target.x, tary-self.focus_distance_to_target.y)
  
  -- draws target
  local mtarx, mtary = self:toCameraCoords((self.origin + self.focus_target):unpack())
  love.graphics.points(mtarx, mtary)
  love.graphics.circle('line', mtarx, mtary, 5)
  --love.graphics.circle('line', mtarx, mtary, self.focus_target:len())
  
  -- draws line from player to target
  --love.graphics.line(px,py,mtarx,mtary)
  --love.graphics.circle('line', px,py,self.MAX_TARGET_DISTANCE)
  
  love.graphics.setColor(142/255, 148/255, 158/255, 1)
  
  -- draws line from origin to target
  local orx, ory = self:toCameraCoords(self.origin:unpack())
  local gugx, gugy = self.origin_distance_to_target:unpack()
  love.graphics.points(orx,ory)
  love.graphics.circle('line', orx, ory, 5)
  love.graphics.line(orx,ory,orx-gugx,ory-gugy)
  
  if self.current_shudder then
    love.graphics.setColor(0.5, 0.5, 0.9, 1)
    local shud_vec = vector(orx, ory) + self.current_shudder:amplitude()
    love.graphics.points(shud_vec:unpack())
    love.graphics.circle('line', shud_vec.x, shud_vec.y, 5)
  end
  
  love.graphics.setColor(0, 1, 0, 1)
    
  -- projected
  local prox, proy = self.focus:projectOn(self.focus_target):unpack()
  --love.graphics.line(px, py, px+prox, py+proy)
  --love.graphics.circle('line', px+prox, py+proy, 5)
  
  love.graphics.setColor(0.5, 0.5, 0.9, 1)
  --difference between projected and target
  local proprox, proproy = (self.focus_target - self.focus:projectOn(self.focus_target)):unpack()
  --love.graphics.line(px+prox, py+proy, px+prox+proprox, py+proy+proproy)
  
  --local beefx, beefy = self.focus_target:projectOn(vector(1,0)):unpack()
  --local beefx, beefy = (vector(1,0) * self.focus_target.x):unpack()
  --love.graphics.line(px, py, px+beefx, py+beefy)
  
  love.graphics.setColor(1, 0, 1, 1)
  
  -- distance to projected
  local hix, hiy = (self.focus - (self.focus:projectOn(self.focus_target))):unpack()
  --love.graphics.line(tarx, tary, tarx-hix, tary-hiy)

  -- this draws the goofy focus movement technique
  local projected = self.focus:projectOn(self.focus_target)
  local parallel = self.focus_target:normalized() * (math.min(math.max((self.focus_target - projected):len() - (self.focus_target:len()*0.7), 0) / (self.focus_target:len()*0.3), 1) * self.EXTRA_LOOKAHEAD + self.STEADY_FOCUS_SPEED)
  if self.focus:projectOn(self.focus_target):len() > self.focus_target:len() then parallel = -parallel end
  if (self.focus_target - self.focus:projectOn(self.focus_target)):len() < 1 then parallel = self.focus_target:normalized() * 0 end

  local perpendistance = -(self.focus - (self.focus:projectOn(self.focus_target)))
  --local perpendistance = -(self.focus - (self.focus_target:normalized() * self.focus:len()))
  local per_speed = math.min(perpendistance:len() / self.MAX_TARGET_DISTANCE, 1) * 150 + 1
  local perpendicular = perpendistance:normalized() * per_speed
    
  if self.focus_target * (self.focus:projectOn(self.focus_target)) < 0 then
    local par_speed = math.min(projected:len() / self.MAX_TARGET_DISTANCE, 1) * 300 + (self.STEADY_FOCUS_SPEED + self.EXTRA_LOOKAHEAD)
    parallel = self.focus_target:normalized() * par_speed
  end
  --local mixed_vector = parallel - (parallel - perpendicular)/2
  --if mixed_vector:len() < self.STEADY_FOCUS_SPEED then mixed_vector = mixed_vector:normalizeInplace() * self.STEADY_FOCUS_SPEED end
  local mixed_vector = parallel + perpendicular
  
  local distance_to_line = (self.focus - (self.focus:projectOn(self.focus_target)))
  --print(distance_to_line:len())
  if distance_to_line:len() < 1 then mixed_vector = parallel end
    
  --love.graphics.line(tarx, tary, tarx + perpendistance.x, tary + perpendistance.y)
  love.graphics.setColor(1, 0.5, 0, 1)
  --love.graphics.line(tarx, tary, tarx + perpendicular.x, tary + perpendicular.y)
  --love.graphics.line(tarx, tary, tarx + parallel.x, tary + parallel.y)
  --love.graphics.line(tarx + perpendicular.x, tary + perpendicular.y, tarx + perpendicular.x + parallel.x, tary + perpendicular.y + parallel.y)
  --love.graphics.line(tarx + parallel.x, tary + parallel.y, tarx + parallel.x + perpendicular.x, tary + parallel.y + perpendicular.y)
  love.graphics.setColor(1, 0, 0, 1)
  --love.graphics.line(tarx,tary,tarx+mixed_vector.x,tary+mixed_vector.y)

  love.graphics.setColor(51/255, 255/255, 230/255, 1)
  --love.graphics.points(self.NATIVE_RES.width/2, self.NATIVE_RES.height/2)
  --love.graphics.rectangle('line', tarx - (self.NATIVE_RES.width/3), tary - (self.NATIVE_RES.height/3), self.NATIVE_RES.width , self.NATIVE_RES.height)
  --love.graphics.line(tarx - (self.NATIVE_RES.width/2), tary - (self.NATIVE_RES.height/2),  tarx - (self.NATIVE_RES.width/2), tary + (self.NATIVE_RES.height/2))
  love.graphics.setColor(1, 1, 1, 1)
  --love.graphics.rectangle('line', self.deadzone.x1, self.deadzone.y1, self.deadzone.x2 - self.deadzone.x1, self.deadzone.y2 - self.deadzone.y1)
end

return CameraWrapper
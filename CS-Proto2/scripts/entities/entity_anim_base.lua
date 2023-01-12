Object = require "libs.classic.classic"
anim8 = require 'libs.anim8.anim8'

utilities = require 'scripts.utilities'
shader_assembler = require 'scripts.shader_wrapper'

EntityAnim = Object:extend()

local pcode = shader_assembler.assembleShader('pixel', 'outline')

function EntityAnim:new(entity, anim_folder, atlas_name)
  self.anims = {}
  self.current_anim = nil
  self.current_ground_level = 0
  self.current_center_position = 0
  self.horizontal_flip = false
  -- wherever you want the left and bottom of your frames to be, relative to the object's position
  --self.image_offset = vector(base_offset_x, base_offset_y)
  self.base_height = entity.base_height
  
  -- this checks that  anim_folder is a string representing a path to the folder containing the atlas and json files describing the animation sheets that make up the atlas
  if type(anim_folder) == 'string' then
    -- only referenced when calling the draw method on the current animation object
    self.sheet = love.graphics.newImage(anim_folder .. atlas_name .. '-sheet.png')
    self.anim_folder = anim_folder
    self.atlas_name = atlas_name
  -- this checks if anim_folder is actually an love.graphics image object, in which case the anim component will be set up as if that image is the only frame the 
elseif type(anim_folder) == 'userdata' then
    local img = anim_folder
    self.sheet = img
    self.anim_folder = nil
    self.atlas_name = nil
    local grid = anim8.newGrid(img:getWidth(), img:getHeight(), img:getWidth(), img:getHeight())
    self:addAnimation('idle', anim8.newAnimation(grid(1, 1), .1, 'pauseAtEnd'), img:getHeight(), img:getWidth()/2)
  else
    error(("Attempted to construct an animation component without correct type for 3rd parameter, errored type: %s"):format(type(anim_folder)))
  end
  
  self.sprite_rot = 0
  self.rot_speed = 0
  -- base_scale is a scalar value represent the scaling of the sprite as a whole, i.e. in both axes. It is 1 by default
  self.base_scale = 1
  -- extra_scale is a vector of scale values added on to base_scale when drawing, allowing scaling either axis independently. It is 0,0 by default
  self.extra_scale = vector(0,0)
  self.anim_timer = Timer.new()
  self.current_shader = love.graphics.newShader(pcode)
  -- we only have to send this to the shader once, since the size of the texture we use never changes
  self.current_shader:send('texture_size', {self.sheet:getPixelDimensions()})
end

function EntityAnim:Get_Draw_Offset(frameWidth, frameHeight)
  -- the below line is basically pushing the sprite up so that the ground level (as defined by me) is at the actual y-position of the enemy, then pushing it down by an arbitrary offset value so that the feet always stay in the same place relative to the actual position of the enemy.
  local offsetY = math.ceil(self.current_ground_level - self.base_height)
  local offsetX = 0
  if self.horizontal_flip then
    offsetX = math.ceil(frameWidth - self.current_center_position)
  else
    offsetX = math.ceil(self.current_center_position)
  end
  return offsetX, offsetY
end  

function EntityAnim:update(dt)
  self.current_anim:update(dt)
  self.anim_timer:update(dt)
  self.sprite_rot = self.sprite_rot + (self.rot_speed * (dt * 10))
end

function EntityAnim:createGrid(sheet_name)
  --[[
  local atlas_json = io.open('assets/basic/sprites/player/' .. atlas_name .. '/' .. atlas_name .. '-sheet.json', "r")
  local atlas_jsonraw = json:read("*all")
  local jsonparse = luna.decode(jsonraw)
  ]]

  local atlas_json = utilities.readFromJson(self.anim_folder .. self.atlas_name.. '-sheet.json')
  
  local atlas_size = atlas_json['meta']['size']
  --print(self.atlas_name .. '-' .. sheet_name .. '.png')
  local sheet_pos = atlas_json['frames'][self.atlas_name .. '-' .. sheet_name .. '.png']['frame']
  --local sheet_pos = atlas_json[atlas_name .. '-' .. sheet_name]
  local sheet = atlas_json['meta']['size']
  
  local sheet_json = utilities.readFromJson(self.anim_folder .. self.atlas_name .. '-' .. sheet_name .. '.json')
  local frame_size = sheet_json['frames'][1]['frame']
  
  --if not frame_size then error("animation you are trying to set up doesn't exist, ya barrel of monkeys!")
  local grid_boy = anim8.newGrid(frame_size['w'], frame_size['h'], atlas_size['w'], atlas_size['h'], sheet_pos['x'], sheet_pos['y'], 0)
  return grid_boy
end

function EntityAnim:draw(x, y)
  local offsetX, offsetY = self:Get_Draw_Offset(self.current_anim:getDimensions())
  -- retrieves the quad that describes the current frame of animation from the animation library
  local spriteQuad = self.current_anim:getFrameInfo()
  -- gets the width and height of the quad, as well as the x and y position of the quad on the spritesheet
  local quadx, quady, quadw, quadh = spriteQuad:getViewport()
  if self.current_shader then 
    love.graphics.setShader(self.current_shader) 
    if self.current_shader:hasUniform('sprite_offset') then self.current_shader:send('sprite_offset', {quadx, quady}) end
    if self.current_shader:hasUniform('sprite_size') then self.current_shader:send('sprite_size', {quadw, quadh}) end
    if self.current_shader:hasUniform('fill_color') then self.current_shader:send('fill_color', {0, 0.3, 1, 1}) end
  end
  self.current_anim:flipH(self.horizontal_flip):draw(self.sheet, x, y, self.sprite_rot, self.base_scale + self.extra_scale.x, self.base_scale + self.extra_scale.y, offsetX, offsetY)
  love.graphics.setShader()
end

function EntityAnim:drawFrameBox(x, y)
  local offsetX, offsetY = self:Get_Draw_Offset(self.current_anim:getDimensions())
  local w, h = self.current_anim:getDimensions()
  love.graphics.rectangle('line', x - offsetX, y - offsetY, w, h)
  --print(self.current_anim:getDimensions())
end

function EntityAnim:addAnimation(name, anim_object, ground_level, center_position)
  if(not self.anims[name]) then
    self.anims[name] = anim_object
    self.anims[name].ground_level = ground_level
    self.anims[name].center_position = center_position
    -- the animation named 'idle' is automatically set as the starting animation
    if name == 'idle' then self:switchAnimation(name) end
  else
    error(("Attempted to add a duplicate animation to an entity, animation name: %s"):format(name))
  end
end

function EntityAnim:switchAnimation(new_anim)
  if(self.anims[new_anim]) then
    self.current_anim = self.anims[new_anim]
    self.current_ground_level = self.current_anim.ground_level
    self.current_center_position = self.current_anim.center_position
    return true
  else
    error(("Attempted to switch to the non-existant animation, %s, on entity {entity code}"):format(new_anim))
  end
end

function EntityAnim:flipSpriteHorizontal(face_direction)
  self.horizontal_flip = face_direction > 0
  --self.current_anim:flipH(face_direction)
end

-- changes speed of the current animation, doesn't persist after the animation ends.
function EntityAnim:changeSpeed(duration)
  self.current_anim:newDurations(duration)
end

-- use this when you want to set the rotation of the entity's sprite AND stop all tweening on the rotation. There are cases where editing the sprite_rot variable directly would make more sense
function EntityAnim:setRotation(rot)
  self.anim_timer:clear()
  self.sprite_rot = rot
end

function EntityAnim:resetRotation()
  self.rot_speed = 0
  -- this all makes it so the enemy rotates in the quickest way to get back to the 360 angle, or no rotation.
  -- it first finds the value it needs to be rotated by to the right to get back to 360..
  local missing = self.sprite_rot % (math.pi*2)
  -- ..then it compares that value with how much it needs to be rotated to the left to get back to 360. The lesser one is take, so the entity always takes the quickest route back to 360.
  local rot_direction = self.sprite_rot - missing
  if missing > (math.pi*2 - missing) then
    rot_direction = self.sprite_rot + (math.pi*2 - missing)
  end
  -- quicker rotation resets will probably be better in the future
  self.anim_timer:tween(0.1, self, {sprite_rot = rot_direction}, 'out-quad', function() sprite_rot = 0 end)
end

function EntityAnim:setCurrentShader(pixel_code, vertex_code)
  -- as long as at least one of the arguments is a string, the newShader value will take it. the order of the paramters doesn't matter
  if pixel_code or vertex_code then
    self.current_shader = love.graphics.newShader(pixel_code, vertex_code)
  end
end

function EntityAnim:getCurrentAnim()
  return self.current_anim
end

return EntityAnim

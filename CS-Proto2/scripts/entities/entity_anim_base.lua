Object = require "libs.classic.classic"
anim8 = require 'libs.anim8.anim8'

utilities = require 'scripts.utilities'

EntityAnim = Object:extend()

function EntityAnim:new(base_offset_x, base_offset_y, anim_folder, atlas_name)
  self.anims = {}
  self.current_anim = nil
  self.current_ground_level = 0
  self.current_center_position = 0
  self.horizontal_flip = false
  self.sheet = love.graphics.newImage(anim_folder .. atlas_name .. '-sheet.png')
  self.anim_folder = anim_folder
  self.atlas_name = atlas_name
  -- wherever you want the left and bottom of your frames to be, relative to the object's position
  self.image_offset = vector(base_offset_x, base_offset_y)
end

function EntityAnim:Get_Draw_Offset(frameWidth, frameHeight)
  -- the below line is basically pushing the sprite up so that the ground level (as defined by me) is at the actual y-position of the enemy, then pushing it down by an arbitrary offset value so that the feet always stay in the same place relative to the actual position of the enemy.
  local offsetY = math.ceil(self.current_ground_level  - self.image_offset.y)
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
  --local drawn_anim = self.horizontal_flip and self.current_anim else return self.current_anim:flipH() end end
  self.current_anim:flipH(self.horizontal_flip):draw(self.sheet, x, y, 0, 1, 1, offsetX, offsetY)
end

function EntityAnim:drawFrameBox(x, y)
  local offsetX, offsetY = self:Get_Draw_Offset(self.current_anim:getDimensions())
  local w, h = self.current_anim:getDimensions()
  love.graphics.rectangle('line', x - offsetX, y - offsetY, w, h)
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

function EntityAnim:getCurrentAnim()
  return self.current_anim
end

function EntityAnim:getBaseImageOffset()
  return self.image_offset
end

return EntityAnim

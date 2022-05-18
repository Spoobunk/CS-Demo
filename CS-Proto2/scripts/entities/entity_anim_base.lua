Object = require "libs.classic.classic"
anim8 = require 'libs.anim8.anim8'

EntityAnim = Object:extend()

function EntityAnim:new(base_offset_x, base_offset_y, sheet)
  self.anims = {}
  self.current_anim = nil
  self.current_ground_level = 0
  self.sheet = sheet
  -- wherever you want the left and bottom of your frames to be, relative to the object's position
  self.image_offset = vector(base_offset_x, base_offset_y)
end

function EntityAnim:Get_Draw_Offset(frameWidth, frameHeight)
  -- the below line is basically pushing the sprite up so that the ground level (as defined by me) is at the actual y-position of the enemy, then pushing it down by an arbitrary offset value so that the feet always stay in the same place relative to the actual position of the enemy.
  local offsetY = math.ceil(self.current_ground_level  - self.image_offset.y)
  local offsetX = math.ceil(frameWidth/2) - 1
  return offsetX, offsetY
end  

function EntityAnim:update(dt)
  self.current_anim:update(dt)
end

function EntityAnim:draw(x,  y)
  local offsetX, offsetY = self:Get_Draw_Offset(self.current_anim:getDimensions())
  self.current_anim:draw(self.sheet, x, y, 0, 1, 1, offsetX, offsetY)
end

function EntityAnim:addAnimation(name, anim_object, ground_level)
  if(not self.anims[name]) then
    self.anims[name] = anim_object
    self.anims[name].ground_level = ground_level
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
    return true
  else
    error(("Attempted to switch to the non-existant animation, %s, on entity {entity code}"):format(new_anim))
  end
end

function EntityAnim:getCurrentAnim()
  return self.current_anim
end

function EntityAnim:getBaseImageOffset()
  return self.image_offset
end

return EntityAnim

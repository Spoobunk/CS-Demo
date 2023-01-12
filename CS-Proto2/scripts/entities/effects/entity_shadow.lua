Entity = require "scripts.entities.entity_base"

Shadow = Entity:extend()

-- @param {entity} parent The parent entity object, the thing casting the shadow
-- @param {int} base_size_x The x-radius of the shadow ellipse at ground level
-- @param {int} base_size_y The y-radius of the shadow ellipse at ground level
function Shadow:new(parent, base_size_x, base_size_y)
  self.parent = parent
  -- the size of the shadow ellipse when at ground level
  self.BASE_SIZE = vector(base_size_x, base_size_y)
  -- the current size of the shadow ellipse
  self.size = self.BASE_SIZE:clone()
  -- the opacity of the shadow ellipse when at ground level
  self.BASE_OPACITY = 0.15
  -- the current opacity of the shadow
  self.opacity = self.BASE_OPACITY
  -- the current scale of the shadow (the base scale is always 1)
  self.scale = 1
  -- the height at which the shadow stops growing bigger and more solid
  self.MAX_HEIGHT = 200
  -- the generic entity constructor is run, with collision and tile_worlds set to nil
  self.super.new(self, self.parent.ground_pos.x, self.parent.ground_pos.y, 0, nil, nil)
end

function Shadow:update(dt)
  -- scale and opacity of the shadow is set proportional to the height of the parent
  --self.scale = 1 + (math.min(self.parent.height / self.MAX_HEIGHT, 1) * 1.5)
  if self.parent.height > 30 then self.scale = 1 + (math.min((self.parent.height - 30) / self.MAX_HEIGHT, 1) * 1.5) else self.scale = 1 end
  self.size = self.BASE_SIZE * self.scale
  self.opacity = self.BASE_OPACITY + (math.min(self.parent.height / self.MAX_HEIGHT, 1) * 0.15)
  
  self:moveTo(vector(self.parent.ground_pos.x, self.parent.ground_pos.y - 2))
end

function Shadow:drawShadow(dt)
  local draw_pos = self.pos:clone()
  if self.parent.current_shudder then draw_pos = draw_pos + self.parent.current_shudder:amplitude() end
  love.graphics.setColor(63/255, 13/255, 163/255, self.opacity)
  love.graphics.ellipse('fill', draw_pos.x, draw_pos.y, self.size.x, self.size.y, 20)
  love.graphics.setColor(1, 1, 1, 1)
end
  
return Shadow
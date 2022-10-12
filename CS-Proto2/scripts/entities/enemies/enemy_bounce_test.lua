Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

utilities = require "scripts.utilities"

AnimComponent = require "scripts.entities.entity_anim_base"
MoveComponent = require "scripts.entities.entity_move_base"
HealthComponent = require "scripts.entities.enemies.enemy_health_base"
Enemy = require "scripts.entities.enemies.enemy_base"

EBT = Enemy:extend()

EBT.state = utilities.deepCopy(EBT.super.state)
EBT.state.alerted.enter = function(self) --[[self:bounce() self.Move:defaultMovementSettings()]] self:rotate() end

function EBT:new(x, y, collision_world, tile_world)
  EBT.super.new(self, x, y, collision_world, tile_world)
  self.name = 'bouncy test enemy'
 
  self.state = EBT.state.idle
  --Anim setup
  local et_sheet = love.graphics.newImage('assets/test/sprites/enemy test sheet.png')
  self.base_image_offset = vector(math.floor(47 / 2), 23)
  self.Anim = AnimComponent(self.base_image_offset.x, self.base_image_offset.y, 'assets/basic/sprites/devout/', 'devout')
  local walk_grid = self.Anim:createGrid('step')
  local idle_grid = self.Anim:createGrid('idle')
  local windup_grid= self.Anim:createGrid('wind up')
  local attack_grid = self.Anim:createGrid('spin')
  self.Anim:addAnimation('walk', anim8.newAnimation(walk_grid('1-2', 1, '1-2', 2), .1), 75, 26)
  self.Anim:addAnimation('idle', anim8.newAnimation(idle_grid('1-2', 1), .5), 77, 23)
  self.Anim:addAnimation('attack_windup', anim8.newAnimation(windup_grid(2, 1), 1, 'pauseAtEnd'), 75, 21)
  self.Anim:addAnimation('attack', anim8.newAnimation(attack_grid('1-2', 1, '1-2', 2), .1), 49, 50)
  
  self.Move = MoveComponent(4, 0.09, 150)
  self.Health = HealthComponent(10, 30, self, self.Anim, self.Move)
  
  self.hitbox = self:addAttackCollider(self.collision_world:circle(self.pos.x, self.pos.y, 20), "Enemy", function() return self.ground_pos:unpack() end, 3, 0.5, 1500) 
  self.alert_trigger_area = self:addCollider(self.collision_world:circle(self.pos.x, self.pos.y, 200), "AlertTrigger", self, function() return self.ground_pos:unpack() end) 
  self:setCollisionResolution('AlertTrigger', 'Player', function() if self:currentStateIs('idle') then self:alertedToPlayer() end end)
  
  self:setUpTileCollider(self.pos.x, self.pos.y, 10, 0, 20, 24)
  self.Anim:switchAnimation('idle')
end

function EBT:instanceThrownCollider()
  self.thrown_hitbox = self:addThrownCollider(self.collision_world:circle(self.pos.x, self.pos.y, 40), function() return self.ground_pos:unpack() end, 30, 0.5)
end

function EBT:update(dt)
  if not self.in_suspense then
    self.Anim:update(dt)
    self.Move:update(dt)
    
  end
  self.Health:update(dt)
  
  if(self.player) then
    self.Anim:flipSpriteHorizontal(self.player_is_to)
  end
  
  EBT.super.update(self, dt)
end

function EBT:draw()
  self.Anim:draw(self.pos.x, self.pos.y)
  -- draw box around current frame
  --self.Anim:drawFrameBox(self.pos.x, self.pos.y)
  love.graphics.setColor(1, 0, 0, 1)
  --love.graphics.rectangle('line', self.pos.x, self.pos.y, self.Anim:getCurrentAnim():getDimensions())
  love.graphics.points(self.pos:unpack())

  self:drawColliders()
  --self:drawTileCollider()
  --self:drawRenderPosition()
  love.graphics.setColor(1, 1, 1, 1)
end

function EBT:bounce()
  self:jump(0.5, 120, 'quad', function() self:bounce() end)
end

function EBT:rotate()
  self.Anim.rot_speed = math.pi/2
  self.main_timer:after(math.random(1,5), function() self.Anim:resetRotation() end)
end

function EBT:alertedToPlayer()
  self:changeStates('alerted')
  self.Anim:switchAnimation('walk')
  self:removeCollider(self.alert_trigger_area)
end

return EBT
Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

AnimComponent = require "scripts.entities.entity_anim_base"
MoveComponent = require "scripts.entities.entity_move_base"

basic_attack = require "scripts.entities.enemies.attack procedures.attack_basic"

Enemy = require "scripts.entities.enemies.enemy_base"

ET = Enemy:extend()
ET.state = {
  idle = {
    enter = function(self) 
      self.Anim:switchAnimation('idle')
      self.facing_player = false
      self.Move:defaultMovementSettings() 
      self.following_player = false
      for i,c in ipairs(self.colliders) do
        if c.tag == "Test" then
          self.collision_world:remove(c)
          table.remove(self.colliders, i)
        end
      end
    end,
    vulnerable = true
  },
  alerted = {
    enter = function(self) 
      self.Anim:switchAnimation('walk')
      self.facing_player = true
      self.Move:defaultMovementSettings() 
      self.following_player = true
      for i,c in ipairs(self.colliders) do
        if c.tag == "Test" then
          self.collision_world:remove(c)
          table.remove(self.colliders, i)
        end
      end
    end,
    vulnerable = true
  },
  attacking = {
    enter = function(self) 

    end,
    vulnerable = true
  }
}

ET.attacks = {
    basic = basic_attack
}
function ET:new(x, y, collision_world)
  ET.super.new(self, x, y, collision_world)
  self.state = ET.state.idle
  self.current_attack = nil
  
  --Anim setup
  local et_sheet = love.graphics.newImage('assets/test/sprites/enemy test sheet.png')
  self.Anim = AnimComponent(math.floor(47 / 2), 23, et_sheet)
  local walk_grid = anim8.newGrid(57, 75, et_sheet:getWidth(), et_sheet:getHeight(), 0, 0, 2)
  local attack_grid = anim8.newGrid(97, 75, et_sheet:getWidth(), et_sheet:getHeight(), 1, 79, 2)
  local idle_grid = anim8.newGrid(47, 78, et_sheet:getWidth(), et_sheet:getHeight(), 235, 0, 2)
  self.Anim:addAnimation('walk', anim8.newAnimation(walk_grid('1-4', 1), .1), 75)
  self.Anim:addAnimation('attack_windup', anim8.newAnimation(attack_grid('1-2', 1), .1, 'pauseAtEnd'), 75)
  self.Anim:addAnimation('attack', anim8.newAnimation(attack_grid('3-4', 1, '1-2', 2), .1), 75)
  self.Anim:addAnimation('idle', anim8.newAnimation(idle_grid('1-2', 1), .5), 77)
  
  -- super slippery movement
  --self.Move = MoveComponent(50, 0.15, 1200)
  self.Move = MoveComponent(4, 0.09, 150)
  
  self:addCollider(self.collision_world:circle(self.pos.x, self.pos.y, 100), "Enemy", self, function() return self.pos:unpack() end) 
  
  -- this is set when the enemy is alerted to the player
  self.trigger_attack_area = nil
  
  
  self.collision_resolution = {
    Player = function() self:alertedToPlayer() end,
    Attack_Trigger = function() self:getInAttackPosition() end
  }
  
  self.following_player = false
  -- variable that saves whether the player was to the right or left of the entity during the last update. For comparing with the current position of the player to decide when to flip the sprite horizontally.
  self.player_was_to = 1
  self.facing_player = true
end

function ET:update(dt)
  ET.super.update(self, dt)
  self.Anim:update(dt)
  self.Move:update(dt)
  if(self.current_attack) then
    self.current_attack:update(dt)
  end

  self.ground_pos = self.ground_pos + self.Move:getMovementStep(dt)
  self.pos = self.ground_pos - vector(0, self.height)
  
  if(self.player and self.following_player) then
    self.Move:setMovementSettings(self.toward_player)
    --self.pos = self.pos + (self.toward_player * self.speed) * (1+dt)
  end
  
  if(self.player and self.facing_player) then
    self.Anim:flipSpriteHorizontal(self.player_is_to)
  end
  
  --self.player_was_to = self.player_is_to
end

function ET:draw()
  self.Anim:draw(self.pos.x, self.pos.y)
  love.graphics.setColor(255, 0, 0, 1)
  --love.graphics.rectangle('line', self.pos.x, self.pos.y, self.Anim:getCurrentAnim():getDimensions())
  love.graphics.points(self.pos:unpack())

  self:drawColliders()
  love.graphics.line(self.pos.x - 30, self:getRenderPosition(), self.pos.x + 30, self:getRenderPosition())
  love.graphics.setColor(255, 255, 255, 1)
end

function ET:alertedToPlayer()
  if(self.state == ET.state.idle) then
    self.state = ET.state.alerted
    self.Anim:switchAnimation('walk')
    local trigger_attack_area = self.collision_world:circle(self.player.position.x, self.player.position.y, 20)
    self:addCollider(trigger_attack_area, "Attack_Trigger", self, function() return self.player.position:unpack() end)
    self.following_player = true
  end
end

function ET:getInAttackPosition()
  if(self.state == ET.state.alerted) then
    self.state = ET.state.attacking
    self.current_attack = basic_attack(self)
    --self.Anim:flipSpriteHorizontal(self.player_is_to)
    --[[self.following_player = false
    local target = vector(self.player.position.x + 10, self.player.position.y)
    local toward_target = target - self.pos
    toward_target = toward_target:normalizeInplace()
    self.Move:setMovementSettings(toward_target)]]
  end
end

function ET:changeStates(to_state)
  self.state = ET.state[to_state]
  ET.state.alerted.enter(self)
end

function ET:getRenderPosition()
  local oy = self.Anim:getBaseImageOffset().y
  return math.floor(((self.pos.y + self.height) + oy) + 0.5)
end
  
return ET
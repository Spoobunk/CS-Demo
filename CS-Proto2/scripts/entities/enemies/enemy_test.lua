Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

AnimComponent = require "scripts.entities.entity_anim_base"
MoveComponent = require "scripts.entities.entity_move_base"
HealthComponent = require "scripts.entities.enemies.enemy_health_base"

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
    end,
    vulnerable = true
  },
  alerted = {
    enter = function(self) 
      self.Anim:switchAnimation('walk')
      self.facing_player = true
      self.Move:defaultMovementSettings() 
      self.following_player = true
      -- this will cause problems with enemies that have multiple attacks.
     --[[ for i,c in ipairs(self.colliders) do
        if c.tag == "Test" then
          self.collision_world:remove(c)
          table.remove(self.colliders, i)
        end
      end
      --]]
    end,
    vulnerable = true
  },
  attacking = {
    enter = function(self) 
      
    end,
    exit = function(self)
      --self.current_attack:exit()
    end,
    vulnerable = true
  },
  hitstun = {
    enter = function(self) 
      self.Anim:switchAnimation('idle')
      self.following_player = true
      self.Anim:flipSpriteHorizontal(self.player_is_to)
    end,
    vulnerable = false
  },
}

ET.attacks = {
    basic = basic_attack
}
function ET:new(x, y, collision_world, tile_world)
  ET.super.new(self, x, y, collision_world, tile_world)
  self.state = ET.state.idle
  self.current_attack = nil
  
  --Anim setup
  local et_sheet = love.graphics.newImage('assets/test/sprites/enemy test sheet.png')
  self.base_image_offset = vector(math.floor(47 / 2), 23)
  self.Anim = AnimComponent(self.base_image_offset.x, self.base_image_offset.y, 'assets/basic/sprites/devout/', 'devout')
  --local walk_grid = anim8.newGrid(57, 75, et_sheet:getWidth(), et_sheet:getHeight(), 0, 0, 2)
  --local attack_grid = anim8.newGrid(97, 75, et_sheet:getWidth(), et_sheet:getHeight(), 1, 79, 2)
  --local idle_grid = anim8.newGrid(47, 78, et_sheet:getWidth(), et_sheet:getHeight(), 235, 0, 2)
  local walk_grid = self.Anim:createGrid('step')
  local idle_grid = self.Anim:createGrid('idle')
  local windup_grid= self.Anim:createGrid('wind up')
  local attack_grid = self.Anim:createGrid('spin')
  --self.Anim:addAnimation('walk', anim8.newAnimation(walk_grid('1-4', 1), .1), 75)
  --self.Anim:addAnimation('attack_windup', anim8.newAnimation(attack_grid('1-2', 1), .1, 'pauseAtEnd'), 75)
  --self.Anim:addAnimation('attack', anim8.newAnimation(attack_grid('3-4', 1, '1-2', 2), .1), 75)
  --self.Anim:addAnimation('idle', anim8.newAnimation(idle_grid('1-2', 1), .5), 77)
  self.Anim:addAnimation('walk', anim8.newAnimation(walk_grid('1-2', 1, '1-2', 2), .1), 75, 26)
  self.Anim:addAnimation('idle', anim8.newAnimation(idle_grid('1-2', 1), .5), 77, 23)
  self.Anim:addAnimation('attack_windup', anim8.newAnimation(windup_grid(2, 1), 1, 'pauseAtEnd'), 75, 21)
  self.Anim:addAnimation('attack', anim8.newAnimation(attack_grid('1-2', 1, '1-2', 2), .1), 49, 50)
  
  -- super slippery movement
  --self.Move = MoveComponent(50, 0.15, 1200)
  self.Move = MoveComponent(4, 0.09, 150)
  self.Health = HealthComponent(24, self, self.Anim, self.Move)
  
  self:addCollider(self.collision_world:circle(self.pos.x, self.pos.y, 20), "Enemy", self, function() return self.pos:unpack() end) 
  self.alert_trigger_area = self:addCollider(self.collision_world:circle(self.pos.x, self.pos.y, 200), "EnemyTrigger", self, function() return self.pos:unpack() end) 
  
  -- this is set when the enemy is alerted to the player
  self.attack_trigger_area = nil
  
  -- How this works: the collision resolution table specifies how to resolve collisions between colliders with certain tags. When a collider attached to this object collides with something, it goes here to look for how to resolve it, using the tag of the collided object.
  self.collision_resolution = {
    Enemy = {Player = function(seperating_vector) local knockback_dir = vector(seperating_vector.x, seperating_vector.y):normalizeInplace() self.Move:setMovementSettings(nil, knockback_dir * 120, nil, nil, nil) end,
              --Attack_Trigger = function() self:getInAttackPosition() end,
              PlayerAttack = function(separating_vector, other) self:abortAttack() self.Health:takeDamage(vector(separating_vector.x, separating_vector.y), other) end,
              Testy = function(separating) normal = vector(separating.x, separating.y) self.Move:setMovementSettings(normal / 2) end},
    EnemyTrigger = {Player = function() if (self.state == ET.state.idle) then self:alertedToPlayer() else self:getInAttackPosition() end end},
    AttackTrigger = {Player = function() self:getInAttackPosition() end},
  }
  
  self.following_player = false
  self.facing_player = true
  
  self:setUpTileCollider(self.pos.x, self.pos.y, 10, 0, 20, 24)
end

function ET:update(dt)
  
  self.Anim:update(dt)
  self.Move:update(dt)
  self.Health:update(dt)
  if(self.current_attack) then
    self.current_attack:update(dt)
  end
  
  if(self.player and self.state == ET.state.alerted) then
    self.Move:setMovementSettings(self.toward_player)
  end
  
  if(self.player and self.facing_player) then
    self.Anim:flipSpriteHorizontal(self.player_is_to)
  end
  
  -- the update function of the superclasses has to come after updating the attack, otherwise the height variable will be all off.
  ET.super.update(self, dt)
end

function ET:draw()
  self.Anim:draw(self.pos.x, self.pos.y)
  -- draw box around current frame
  --self.Anim:drawFrameBox(self.pos.x, self.pos.y)
  love.graphics.setColor(1, 0, 0, 1)
  --love.graphics.rectangle('line', self.pos.x, self.pos.y, self.Anim:getCurrentAnim():getDimensions())
  love.graphics.points(self.pos:unpack())

  self:drawColliders()
  self:drawTileCollider()
  self:drawRenderPosition()
  love.graphics.setColor(1, 1, 1, 1)
end

function ET:alertedToPlayer()
  if(self.state == ET.state.idle) then
    self.state = ET.state.alerted
    self.Anim:switchAnimation('walk')
    self:removeCollider(self.alert_trigger_area)
    local attack_trigger_area = self.collision_world:circle(self.pos.x, self.pos.y, 100)
    self:addCollider(attack_trigger_area, "AttackTrigger", self, function() return self.pos:unpack() end)
    self.following_player = true
  end
end

function ET:getInAttackPosition()
  if(self.state == ET.state.alerted) then
    self.state = ET.state.attacking
    self.current_attack = basic_attack(self)
  end
end

function ET:abortAttack()
  if(self.current_attack) then
    self.current_attack:exit()
  end
end

function ET:changeStates(to_state)
  -- calls the exit method on the last state if one is provided
  if self.state.exit then self.state.exit(selfz) end
  self.state = ET.state[to_state]
  self.state.enter(self)
end

return ET
Object = require "libs.classic.classic"
Entity = require "scripts.entities.entity_base"
Enemy = require "scripts.entities.enemies.enemy_base"
Active = require "scripts.entities.entity_active_base"

Entity_Manager = Object:extend()
Entity_Manager.entities = {}

function Entity_Manager.drawEntities() 
    for _, e in ipairs(Entity_Manager.entities) do
    if e:is(Active) or e:is(Player) then e:drawShadow() end
  end
  for _, e in ipairs(Entity_Manager.entities) do
    e:draw()
  end
end

function Entity_Manager.updateEntities(dt)
  for _, e in ipairs(Entity_Manager.entities) do
    --if e:is(Player) then e:update(dt, movex, movey) end
    if not e:is(Scenery) and not e:is(Player) then e:update(dt) end
  end
end

function Entity_Manager.updateRenderOrder()
  table.sort(Entity_Manager.entities, function(first, second) return first:getRenderPosition() < second:getRenderPosition() end)
  
end
    
function Entity_Manager:addEntity(e)
  if e:is(Entity) then table.insert(Entity_Manager.entities, e) else error("attempted to create an entity that did not extend the Entity base class") end
  Entity_Manager.updateRenderOrder()
end
  
function Entity_Manager:removeEntity(target)
  for i, e in ipairs(Entity_Manager.entities) do
    if e == target then table.remove(Entity_Manager.entities, i) end
  end
end
  
return Entity_Manager

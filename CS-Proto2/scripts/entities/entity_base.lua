Object = require "libs.classic.classic"

Entity = Object:extend()

function Entity:getRenderPosition() print("you're not overriding the base entity getrenderposition method ya turkey") end

return Entity
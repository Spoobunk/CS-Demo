Gamestate = require "libs.hump.gamestate"
state_manager = require "scripts.state_manager"

function love.load()
  --love.graphics.setDefaultFilter("nearest", "nearest", 1)
  --love.graphics.setLineStyle("rough")
  Gamestate.registerEvents()
  Gamestate.switch(state_manager.game)
end

function love.update()
  if love.keyboard.isDown("escape") then 
    love.event.quit()
  end
end

function love.draw()
  
end
Object = require "libs.classic.classic"

Base_State = Object:extend()

function Base_State:enter_state()
    print("player should not be entering this state")
end

--Base_State.state_manager = require "scripts.player.player_state"
Base_State.input = {
  attack = "example",
  spin = nil,
  grab = nil,
  release_attack = nil, 
  release_spin = nil,
  release_grab = nil
}

Base_State.name = "base"
Base_State.canMove = false
Base_State.vulnerable = true

return Base_State
Base_State = require "scripts.player.player states.base_state"

Moving_State = Base_State:extend()

function Moving_State:enter_state()
    --print("moving")
end

--Idle_State.input = Idle_State.super.input
Moving_State.input = {
  attack = nil,
  spin = "do spin",
  grab = "do grab",
  release_attack = nil, 
  release_spin = nil,
  release_grab = nil
}

Moving_State.name = "moving"
Moving_State.canMove = true

return Moving_State
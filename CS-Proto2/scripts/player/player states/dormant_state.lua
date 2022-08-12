Base_State = require "scripts.player.player states.base_state"

Dormant_State = Base_State:extend()

function Dormant_State:enter_state(state_manager, from_state)
    --print("attack")
end

function Dormant_State.exit(state_manager, to_state)
  
end

Dormant_State.input = {
  attack = nil,
  spin = nil,
  grab = nil,
  release_attack = nil, 
  release_spin = nil,
  release_grab = nil
}

Dormant_State.name = "dormant"
Dormant_State.canMove = false
Dormant_State.vulnerable = true
Dormant_State.flip_sprite_horizontal = false

return Dormant_State
Base_State = require "scripts.player.player states.base_state"

Throwing_State = Base_State:extend()

function Throwing_State.enter_state(state_manager, from_state)
    --print("attack")
end

function Throwing_State.exit(state_manager, to_state)
  
end

Throwing_State.input = {
  attack = nil,
  spin = nil,
  grab = nil,
  release_attack = nil, 
  release_spin = nil,
  release_grab = {'grab', 'doThrow'}
}

Throwing_State.name = "throwing"
Throwing_State.canMove = false
Throwing_State.vulnerable = true
Throwing_State.flip_sprite_horizontal = false

return Throwing_State
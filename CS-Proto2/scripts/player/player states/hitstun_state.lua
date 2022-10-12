Base_State = require "scripts.player.player states.base_state"

HitstunState = Base_State:extend()

function HitstunState.enter_state(state_manager, from_state)
    --print(state_manager.buffered_input)
    --state_manager.player_components.attack:
    state_manager.player_components.anim:Switch_Animation('mashready2')
    --state_manager.player_components.grab:endGrab()
end

HitstunState.input = {
  attack = nil,
  spin = nil,
  grab = nil,
  release_attack = nil, 
  release_spin = nil,
  release_grab = nil
}

HitstunState.name = "hitstun"
HitstunState.canMove = true
HitstunState.vulnerable = false
HitstunState.flip_sprite_horizontal = false

return HitstunState
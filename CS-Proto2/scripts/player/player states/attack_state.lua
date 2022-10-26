Base_State = require "scripts.player.player states.base_state"

Attack_State = Base_State:extend()

function Attack_State.enter_state(state_manager, from_state)

end

function Attack_State.exit(state_manager, to_state)
  state_manager.player_components.attack:exit_attack(to_state)
  state_manager:setInputBuffering('all', false)
end

--Idle_State.input = Idle_State.super.input
--Idle_State.input.attack = "move", "spin"
--Idle_State.input.spin = "do spin"
--Idle_State.input.grab = "do grab"

Attack_State.input = {
  attack = {'attack', 'attackInput'},
  spin = nil,
  grab = nil,
  release_attack = {'attack', 'releaseAttack'}, 
  release_spin = nil,
  release_grab = nil
}

Attack_State.name = "attack"
Attack_State.canMove = false
Attack_State.vulnerable = true
Attack_State.flip_sprite_horizontal = false
Attack_State.moveCamera = 'always'
Attack_State.moveCameraTarget = false
Attack_State.moveCameraFocusMethod = 'normal'

return Attack_State
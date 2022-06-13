Base_State = require "scripts.player.player states.base_state"

Attack_State = Base_State:extend()

function Attack_State:enter_state()
    --print("attack")
end

--Idle_State.input = Idle_State.super.input
--Idle_State.input.attack = "move", "spin"
--Idle_State.input.spin = "do spin"
--Idle_State.input.grab = "do grab"

Attack_State.input = {
  attack = {'attack', 'attackInput'},
  spin = nil,
  grab = nil,
}

Attack_State.name = "attack"
Attack_State.canMove = false

return Attack_State
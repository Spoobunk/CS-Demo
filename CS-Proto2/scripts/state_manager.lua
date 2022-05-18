game = require "scripts.states.game_state"
menu = require "scripts.states.menu_state"

-- A list of all game states. All states are exposed to the state-defining classes through this table.
states = {
    ['game'] = game,
    ['menu'] = menu
}

return states
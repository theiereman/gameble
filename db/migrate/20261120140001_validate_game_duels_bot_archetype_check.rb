class ValidateGameDuelsBotArchetypeCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_duels, name: "game_duels_bot_archetype_check"
  end
end

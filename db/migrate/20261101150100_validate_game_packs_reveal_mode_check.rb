class ValidateGamePacksRevealModeCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_packs, name: "game_packs_reveal_mode_check"
  end
end

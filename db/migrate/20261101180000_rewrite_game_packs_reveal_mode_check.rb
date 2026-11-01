class RewriteGamePacksRevealModeCheck < ActiveRecord::Migration[8.1]
  def up
    safety_assured { remove_check_constraint :game_packs, name: "game_packs_reveal_mode_check" }
    add_check_constraint :game_packs, "reveal_mode IS NULL OR reveal_mode = 'all' OR reveal_mode = 'one_by_one'",
      name: "game_packs_reveal_mode_values_check", validate: false
  end

  def down
    remove_check_constraint :game_packs, name: "game_packs_reveal_mode_values_check"
    add_check_constraint :game_packs, "reveal_mode IS NULL OR reveal_mode IN ('all', 'one_by_one')",
      name: "game_packs_reveal_mode_check", validate: false
  end
end

class AddRevealModeToGamePacks < ActiveRecord::Migration[8.1]
  def change
    add_column :game_packs, :reveal_mode, :string
    add_check_constraint :game_packs, "reveal_mode IS NULL OR reveal_mode IN ('all', 'one_by_one')",
      name: "game_packs_reveal_mode_check", validate: false
  end
end

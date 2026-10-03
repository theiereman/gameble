# Validates the check on a pack's cards added without validation
# (strong_migrations).
class ValidateGamePacksCardSeasonIdsCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_packs, name: "game_packs_card_season_ids_check"
  end
end

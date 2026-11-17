class ValidateGamePacksAndGameFortunesDuelChecks < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_packs, name: "game_packs_kind_check"
    validate_check_constraint :game_packs, name: "game_packs_card_season_ids_check"
    validate_check_constraint :game_packs, name: "game_packs_duel_day_check"
    validate_check_constraint :game_fortunes, name: "game_fortunes_packs_check"
  end
end

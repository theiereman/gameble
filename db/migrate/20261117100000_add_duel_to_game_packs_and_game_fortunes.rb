class AddDuelToGamePacksAndGameFortunes < ActiveRecord::Migration[8.1]
  def change
    add_column :game_packs, :duel_day, :date
    add_column :game_fortunes, :duel_packs, :integer, default: 0, null: false

    remove_check_constraint :game_packs, "kind = 'regular' OR kind = 'bonus' OR kind = 'reward'", name: "game_packs_kind_check"
    add_check_constraint :game_packs, "kind = 'regular' OR kind = 'bonus' OR kind = 'reward' OR kind = 'duel'",
      name: "game_packs_kind_check", validate: false

    remove_check_constraint :game_packs,
      "array_ndims(card_season_ids) = 1 AND cardinality(card_season_ids) >= 1 AND array_position(card_season_ids, NULL::bigint) IS NULL " \
      "AND (kind <> 'regular' OR cardinality(card_season_ids) = 5) AND (kind <> 'bonus' OR cardinality(card_season_ids) = 3)",
      name: "game_packs_card_season_ids_check"
    add_check_constraint :game_packs,
      "array_ndims(card_season_ids) = 1 AND cardinality(card_season_ids) >= 1 AND array_position(card_season_ids, NULL::bigint) IS NULL " \
      "AND (kind <> 'regular' OR cardinality(card_season_ids) = 5) AND (kind <> 'bonus' OR cardinality(card_season_ids) = 3) " \
      "AND (kind <> 'duel' OR cardinality(card_season_ids) = 3)",
      name: "game_packs_card_season_ids_check", validate: false

    add_check_constraint :game_packs, "(kind = 'duel') = (duel_day IS NOT NULL)", name: "game_packs_duel_day_check", validate: false

    remove_check_constraint :game_fortunes, "regular_packs >= 0 AND bonus_packs >= 0 AND reward_packs >= 0", name: "game_fortunes_packs_check"
    add_check_constraint :game_fortunes, "regular_packs >= 0 AND bonus_packs >= 0 AND reward_packs >= 0 AND duel_packs >= 0",
      name: "game_fortunes_packs_check", validate: false
  end
end

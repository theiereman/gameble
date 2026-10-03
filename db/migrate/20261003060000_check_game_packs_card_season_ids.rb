# A pack's cards checked by the database (epic 3 retrospective, O2): a
# one-dimensional list of at least one card-season id, none of them NULL,
# exactly five for a regular pack (Game::Pack::SIZE) and three for a daily
# bonus pack (Game::Pack::BONUS_SIZE); a reward pack holds one or more. The
# sizes are written out, as a migration must not change when the code does.
#
# The check is added without validation and validated in the next migration,
# so adding it does not block the table (strong_migrations).
class CheckGamePacksCardSeasonIds < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :game_packs,
      "array_ndims(card_season_ids) = 1 AND cardinality(card_season_ids) >= 1 " \
      "AND array_position(card_season_ids, NULL) IS NULL " \
      "AND (kind <> 'regular' OR cardinality(card_season_ids) = 5) " \
      "AND (kind <> 'bonus' OR cardinality(card_season_ids) = 3)",
      name: "game_packs_card_season_ids_check", validate: false
  end
end

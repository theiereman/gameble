# The contract step for `dust_tier`: dust is gone
# from the design, the release date gives only the card's year and the sets,
# and no code reads the column. Catalog::CardSeason ignores it
# (`ignored_columns`), which strong_migrations requires before the removal.
#
# Deploy order: the code before this migration still writes `dust_tier`
# (Catalog::UpsertDraftCard in the import worker, Catalog::PublishSeason in
# the back-office). Deploy with no import run running and no season being
# published; `db:prepare` runs this migration once when the new web container
# boots, while the old containers still serve. The new code ignores the
# column, so a process booted before the migration ran is safe too.
class RemoveDustTierFromCatalogCardSeasons < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :catalog_card_seasons, "dust_tier BETWEEN 0 AND 4", name: "catalog_card_seasons_dust_tier_check"
    safety_assured { remove_column :catalog_card_seasons, :dust_tier, :integer, limit: 2 }
  end
end

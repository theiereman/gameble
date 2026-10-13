# What a set asks of a player at each tier: bronze, silver and gold on a
# theme, and complete on every set, written once when the season is
# published.
class CreateCatalogSetTiers < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_set_tiers do |t|
      t.references :set, null: false, index: false, foreign_key: { to_table: :catalog_sets }
      t.string :tier, null: false
      t.integer :required, null: false
      t.timestamps

      t.check_constraint "tier IN ('bronze', 'silver', 'gold', 'complete')", name: "catalog_set_tiers_tier_check"
      t.check_constraint "required > 0", name: "catalog_set_tiers_required_check"
      t.index %i[set_id tier], unique: true
    end
  end
end

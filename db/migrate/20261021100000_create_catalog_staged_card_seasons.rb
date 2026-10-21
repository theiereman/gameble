# The scores an import run stages beside the draft season until the administrator promotes them.
class CreateCatalogStagedCardSeasons < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_staged_card_seasons do |t|
      t.string :batch_token, null: false
      t.references :card, null: false, index: false, foreign_key: { to_table: :catalog_cards }
      t.float :prestige_score, null: false
      t.integer :prestige_score_version, limit: 2
      t.decimal :rating, precision: 5, scale: 2, null: false
      t.integer :review_count
      t.timestamps

      t.index %i[batch_token card_id], unique: true
      t.index :card_id
      t.check_constraint "rating >= 0 AND rating <= 100", name: "catalog_staged_card_seasons_rating_check"
      t.check_constraint "review_count IS NULL OR review_count >= 1", name: "catalog_staged_card_seasons_review_count_check"
    end
  end
end

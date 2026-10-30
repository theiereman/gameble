# The link-preview image of a published card-season in one language: its
# PNG is an Active Storage attachment, served by its token; the fingerprint
# names the card view and render it was drawn from.
class CreateCatalogShareImages < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_share_images do |t|
      t.references :card_season, null: false, index: false, foreign_key: { to_table: :catalog_card_seasons }
      t.string :locale, null: false
      t.string :token, null: false, index: { unique: true }
      t.string :fingerprint, null: false
      t.timestamps

      t.index %i[card_season_id locale], unique: true
      t.check_constraint "locale = 'en' OR locale = 'fr'", name: "catalog_share_images_locale_check"
    end
  end
end

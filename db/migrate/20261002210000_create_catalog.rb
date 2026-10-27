# The catalog: cards and their texts per locale,
# seasons, a card's scores, rarity and dust tier for a season, and the sets of
# a season. Nothing here names a source: a card is keyed by an opaque source
# key built by whoever writes it.
#
# Status checks are written with OR: the IN (...) form dumps unstably.
class CreateCatalog < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_cards do |t|
      t.string :source_key, null: false
      t.string :slug, null: false
      t.date :release_date, null: false
      t.string :image_url, null: false
      t.string :store_url, null: false
      t.string :publisher
      t.string :credit
      # Ordered, primary genre first.
      t.string :genres, array: true, null: false, default: []
      t.string :tags, array: true, null: false, default: []
      t.timestamps

      t.index :source_key, unique: true
      t.index :slug, unique: true
    end

    create_table :catalog_card_texts do |t|
      t.references :card, null: false, index: false, foreign_key: { to_table: :catalog_cards }
      t.string :locale, null: false
      t.string :title, null: false
      t.text :short_description
      t.timestamps

      t.check_constraint "locale = 'en' OR locale = 'fr'", name: "catalog_card_texts_locale_check"
      t.index [ :card_id, :locale ], unique: true
    end

    create_table :catalog_seasons do |t|
      t.integer :number, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :published_at
      t.timestamps

      t.check_constraint "status = 'draft' OR status = 'published'", name: "catalog_seasons_status_check"
      t.index :number, unique: true
      # One draft at a time: every draft row indexes the same constant.
      t.index "(true)", unique: true, where: "status = 'draft'", name: "index_catalog_seasons_one_draft"
    end

    # A card in a season. Scores follow the source while the season is a
    # draft; rarity and dust tier stay NULL until the season is published,
    # then never change.
    create_table :catalog_card_seasons do |t|
      t.references :card, null: false, index: false, foreign_key: { to_table: :catalog_cards }
      t.references :season, null: false, foreign_key: { to_table: :catalog_seasons }
      t.float :prestige_score, null: false
      t.decimal :rating, precision: 5, scale: 2, null: false
      t.integer :rarity, limit: 2
      t.integer :dust_tier, limit: 2
      t.timestamps

      t.check_constraint "rating BETWEEN 0 AND 100", name: "catalog_card_seasons_rating_check"
      t.check_constraint "rarity BETWEEN 1 AND 5", name: "catalog_card_seasons_rarity_check"
      t.check_constraint "dust_tier BETWEEN 0 AND 4", name: "catalog_card_seasons_dust_tier_check"
      t.index [ :card_id, :season_id ], unique: true
    end

    create_table :catalog_sets do |t|
      t.references :season, null: false, index: false, foreign_key: { to_table: :catalog_seasons }
      t.string :kind, null: false
      t.string :key, null: false
      t.timestamps

      t.check_constraint "kind = 'publisher' OR kind = 'tome' OR kind = 'best_of_year'", name: "catalog_sets_kind_check"
      t.index [ :season_id, :kind, :key ], unique: true
    end

    create_table :catalog_set_memberships do |t|
      t.references :set, null: false, index: false, foreign_key: { to_table: :catalog_sets }
      t.references :card_season, null: false, foreign_key: { to_table: :catalog_card_seasons }
      t.integer :position, null: false
      t.timestamps

      t.index [ :set_id, :card_season_id ], unique: true
    end
  end
end

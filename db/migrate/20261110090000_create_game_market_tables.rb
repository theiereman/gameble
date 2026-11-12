# The market's money and its settings: one insert-only version of every economy value per row, a wallet per player, the permanent record
# of every PiCoin movement, and the copies each player has entrusted. Nothing here is read by an existing table.
class CreateGameMarketTables < ActiveRecord::Migration[8.1]
  RARITIES = %w[common uncommon rare epic legendary].freeze
  LEDGER_KINDS = %w[mint stamp hold release purchase sale commission forfeit].freeze

  def change
    create_table :game_market_settings do |t|
      t.string :token, null: false, index: { unique: true }
      RARITIES.each { |rarity| t.bigint :"entrustment_#{rarity}", null: false }
      RARITIES.each { |rarity| t.bigint :"stamp_#{rarity}", null: false }
      RARITIES.each { |rarity| t.bigint :"minimum_price_#{rarity}", null: false }
      t.integer :commission_basis_points, null: false
      t.bigint :daily_cap, null: false
      t.integer :duration_short_hours, null: false
      t.integer :duration_medium_hours, null: false
      t.integer :duration_long_hours, null: false
      t.integer :preselected_duration_hours, null: false
      t.integer :increment_basis_points, null: false
      t.integer :soft_close_seconds, null: false
      t.integer :average_sale_count, null: false
      t.integer :average_window_days, null: false
      t.integer :feed_threshold_multiple, null: false
      t.integer :unusual_maximum_multiple, null: false
      t.integer :alert_destroyed_share_basis_points
      t.bigint :alert_picoins_per_player
      t.integer :alert_top_share_basis_points
      RARITIES.each { |rarity| t.decimal :"income_days_target_#{rarity}", precision: 10, scale: 3 }
      t.boolean :open, null: false, default: false
      t.datetime :terms_confirmed_at
      t.datetime :odds_confirmed_at
      t.datetime :first_opened_at
      t.references :author, foreign_key: { to_table: :accounts_players }
      t.references :replaces, index: { unique: true }, foreign_key: { to_table: :game_market_settings }
      t.datetime :created_at, null: false

      t.check_constraint "commission_basis_points BETWEEN 0 AND 2500", name: "game_market_settings_commission_check"
      t.check_constraint "daily_cap > 0 AND increment_basis_points > 0 AND soft_close_seconds > 0", name: "game_market_settings_positive_check"
      t.check_constraint "preselected_duration_hours IN (duration_short_hours, duration_medium_hours, duration_long_hours)",
        name: "game_market_settings_preselected_check"
    end

    create_table :game_market_wallets do |t|
      t.references :player, null: false, index: { unique: true }, foreign_key: { to_table: :accounts_players }
      t.bigint :available, null: false, default: 0
      t.bigint :committed, null: false, default: 0
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.check_constraint "available >= 0 AND committed >= 0", name: "game_market_wallets_balance_check"
    end

    create_table :game_market_ledger_entries do |t|
      t.references :player, null: false, foreign_key: { to_table: :accounts_players }
      t.string :kind, null: false
      t.bigint :available_delta, null: false, default: 0
      t.bigint :committed_delta, null: false, default: 0
      t.bigint :listing_id
      t.references :settings, null: false, foreign_key: { to_table: :game_market_settings }
      t.datetime :created_at, null: false

      t.check_constraint "kind ~ '^(#{LEDGER_KINDS.join("|")})$'", name: "game_market_ledger_entries_kind_check"
    end

    create_table :game_market_archive_deposits do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :card_season, null: false, foreign_key: { to_table: :catalog_card_seasons }
      t.integer :quantity, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index %i[player_id card_season_id], unique: true, name: "index_game_market_archive_deposits_uniqueness"
      t.check_constraint "quantity > 0", name: "game_market_archive_deposits_quantity_check"
    end
  end
end

class AddArchiveAndSlotPricesToGameMarketSettings < ActiveRecord::Migration[8.1]
  RARITIES = %w[common uncommon rare epic legendary].freeze
  SLOT_PRICES = {
    goal: { 6 => 500, 7 => 1_000, 8 => 2_000, 9 => 3_000, 10 => 5_000 },
    custom_set: { 6 => 500, 7 => 1_000, 8 => 2_000, 9 => 3_000, 10 => 5_000 },
    deck: { 4 => 1_000, 5 => 2_000 }
  }.freeze

  def change
    RARITIES.each { add_column :game_market_settings, :"archive_price_#{it}", :bigint }
    SLOT_PRICES.each do |kind, prices|
      prices.each { |slot, price| add_column :game_market_settings, :"slot_price_#{kind}_#{slot}", :bigint, null: false, default: price }
    end
    RARITIES.each do |rarity|
      add_check_constraint :game_market_settings, "archive_price_#{rarity} IS NULL OR archive_price_#{rarity} >= minimum_price_#{rarity}",
        name: "game_market_settings_archive_price_#{rarity}_check", validate: false
    end
  end
end

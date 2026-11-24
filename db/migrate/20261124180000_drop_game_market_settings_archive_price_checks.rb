class DropGameMarketSettingsArchivePriceChecks < ActiveRecord::Migration[8.1]
  def change
    %w[common uncommon rare epic legendary].each do |rarity|
      remove_check_constraint :game_market_settings, "archive_price_#{rarity} IS NULL OR archive_price_#{rarity} >= minimum_price_#{rarity}",
        name: "game_market_settings_archive_price_#{rarity}_check"
    end
  end
end

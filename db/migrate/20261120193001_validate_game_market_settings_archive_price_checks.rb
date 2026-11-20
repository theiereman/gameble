class ValidateGameMarketSettingsArchivePriceChecks < ActiveRecord::Migration[8.1]
  def change
    %w[common uncommon rare epic legendary].each do |rarity|
      validate_check_constraint :game_market_settings, name: "game_market_settings_archive_price_#{rarity}_check"
    end
  end
end

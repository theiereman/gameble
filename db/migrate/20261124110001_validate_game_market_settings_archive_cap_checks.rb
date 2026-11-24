class ValidateGameMarketSettingsArchiveCapChecks < ActiveRecord::Migration[8.1]
  def change
    %w[rare epic legendary].each do |rarity|
      validate_check_constraint :game_market_settings, name: "game_market_settings_archive_cap_#{rarity}_check"
      validate_check_constraint :game_market_settings, name: "game_market_settings_archive_cap_window_days_#{rarity}_check"
    end
  end
end

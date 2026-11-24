class AddArchiveCapsToGameMarketSettings < ActiveRecord::Migration[8.1]
  CAPS = {
    rare: { cap: 1, window_days: 1 },
    epic: { cap: 1, window_days: 7 },
    legendary: { cap: 1, window_days: 7 }
  }.freeze

  def change
    CAPS.each do |rarity, defaults|
      add_column :game_market_settings, :"archive_cap_#{rarity}", :bigint, null: false, default: defaults[:cap]
      add_column :game_market_settings, :"archive_cap_window_days_#{rarity}", :bigint, null: false, default: defaults[:window_days]
      %W[archive_cap_#{rarity} archive_cap_window_days_#{rarity}].each do |column|
        add_check_constraint :game_market_settings, "#{column} >= 1", name: "game_market_settings_#{column}_check", validate: false
      end
    end
  end
end

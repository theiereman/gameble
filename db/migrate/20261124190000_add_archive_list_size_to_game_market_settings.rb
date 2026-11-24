class AddArchiveListSizeToGameMarketSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :game_market_settings, :archive_list_size, :integer, null: false, default: 20
  end
end

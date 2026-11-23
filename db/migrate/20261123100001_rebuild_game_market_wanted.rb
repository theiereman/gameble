class RebuildGameMarketWanted < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    failed_player_ids = Game::Market::RebuildAllWantedJob.perform_now
    raise "the wanted rows of players #{failed_player_ids.join(", ")} were not rebuilt" if failed_player_ids.any?
  end

  def down
  end
end

class RebuildGameMarketWanted < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    Game::Market::RebuildAllWantedJob.perform_now
  end

  def down
  end
end

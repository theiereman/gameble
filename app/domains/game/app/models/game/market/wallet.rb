module Game
  module Market
    # A player's PiCoins; only Ledger changes it. A player with no row has none.
    class Wallet < ApplicationRecord
      self.table_name = "game_market_wallets"
    end
  end
end

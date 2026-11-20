module Game
  module Market
    class TiedAccount < ApplicationRecord
      self.table_name = "game_market_tied_accounts"

      belongs_to :low_account, class_name: "Accounts::Player"
      belongs_to :high_account, class_name: "Accounts::Player"

      validates :signal, inclusion: { in: ->(_) { AltSignals::TYING } }
    end
  end
end

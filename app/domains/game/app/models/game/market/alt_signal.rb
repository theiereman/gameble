module Game
  module Market
    class AltSignal < ApplicationRecord
      self.table_name = "game_market_alt_signals"

      belongs_to :account, class_name: "Accounts::Player"
      belongs_to :other_account, class_name: "Accounts::Player", optional: true

      validates :signal, inclusion: { in: ->(_) { AltSignals::SIGNALS } }
    end
  end
end

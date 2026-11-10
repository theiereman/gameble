module Game
  module Market
    # What staff are told about an account that opens or trades like an alt account; replaced every night, never shown to a player.
    class AltSignal < ApplicationRecord
      self.table_name = "game_market_alt_signals"

      belongs_to :account, class_name: "Accounts::Player"
      belongs_to :other_account, class_name: "Accounts::Player", optional: true

      validates :signal, inclusion: { in: ->(_) { AltSignals::SIGNALS } }
    end
  end
end

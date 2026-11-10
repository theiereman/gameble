module Game
  module Market
    # Where PiCoins are created. Only EntrustCards calls it.
    module Mint
      def self.credit(player_id:, amount:, settings_id:)
        Ledger.post([ Ledger::Entry.new(player_id:, kind: :mint, available_delta: amount, settings_id:) ])
      end
    end
  end
end

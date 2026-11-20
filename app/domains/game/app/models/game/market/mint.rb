module Game
  module Market
    # Where PiCoins are created. Only the entrust step calls it; it returns the entry for the caller's single post.
    module Mint
      def self.credit(player_id:, amount:, settings_id:) = Ledger::Entry.new(player_id:, kind: :mint, available_delta: amount, settings_id:)
    end
  end
end

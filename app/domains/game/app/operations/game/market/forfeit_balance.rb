module Game
  module Market
    class ForfeitBalance < Operation
      NOTHING_TO_FORFEIT = Dry::Monads::Failure(:nothing_to_forfeit)
      MARKET_PENDING = Dry::Monads::Failure(:market_pending)
      SKIPPED = [ NOTHING_TO_FORFEIT, MARKET_PENDING ].freeze

      def call(player:)
        player = step require_account(player)

        transaction do
          TradeLocks.players(player.id)
          step deleted(player)
          wallet = Wallet.lock.find_by(player_id: player.id)
          step settled(player, wallet)
          amount = wallet.available
          Ledger.post(entry(player, amount))
          step publish(BalanceForfeited.new(data: { player_id: player.id, amount: }), stream_name: stream_name(player.id))
          amount
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def deleted(player) = Accounts::Player.where(id: player.id).where.not(deleted_at: nil).exists? ? Success() : Failure(:player_not_deleted)

      def settled(player, wallet)
        return NOTHING_TO_FORFEIT unless wallet
        return MARKET_PENDING if wallet.committed.positive? || open_listing?(player)

        wallet.available.positive? ? Success() : NOTHING_TO_FORFEIT
      end

      def open_listing?(player) = Listing.open_now.where(seller_id: player.id).or(Listing.open_now.where(leader_id: player.id)).exists?

      def entry(player, available)
        Ledger::Entry.new(player_id: player.id, kind: :forfeit, available_delta: -available, committed_delta: 0, listing_id: nil, settings_id: CurrentSettings.call.id)
      end
    end
  end
end

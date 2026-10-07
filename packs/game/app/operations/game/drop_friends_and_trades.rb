module Game
  # Cuts a deleted or banned player off from the other players (R6, AD-14):
  # their open trades close as `cancelled` and every copy those trades
  # reserved is released, on either side; their invitations, sent or
  # received, and their friendships are deleted. The trades stay, as the
  # other party's history ("CLOS"). Publishes nothing: it runs from a
  # handler (AD-10), so the other party sees it at their next render.
  #
  # Run by Game::ReleasePlayer (a deletion, before the record is
  # anonymised), by Game::Handlers::PlayerBanned and by
  # Game::DropFriendsAndTradesJob, never for a player in good standing.
  #
  # Locks (AD-10): the bank locks of the player and of every party to their
  # open trades, in ascending player id, then those trade rows, then the
  # offered holdings by ascending proposer and card-season. Every trade
  # operation takes both parties' bank locks, so once the player's own is
  # held their open trades can no longer change; a partner whose trade
  # appeared between the first read and that lock is locked afterwards, out
  # of order (rare: a deadlock then aborts one of the two, and a deletion
  # rolls back whole). Invitations are deleted before friendships: an
  # acceptance holding an invitation's row commits its friendship first,
  # which is then deleted; a later one finds no invitation.
  #
  #   Game::DropFriendsAndTrades.new.call(player:)
  #   # => Success(player) | Failure(:player_required)
  class DropFriendsAndTrades < Operation
    include TradeSteps

    def call(player:)
      player = step require_record(player)

      transaction do
        now = Time.current
        trades = lock_open_trades(player)
        release_offers(trades, now)
        Trade.where(id: trades.map(&:id)).update_all(status: "cancelled", closed_at: now, updated_at: now)
        Invitation.where(sender_id: player.id).or(Invitation.where(recipient_id: player.id)).delete_all
        Friendship.of(player.id).delete_all
        player
      end
    end

    private

    # Not `require_player`: a banned player, or one whose deletion is under
    # way, is who this runs for.
    def require_record(player)
      player.is_a?(Accounts::Player) && player.persisted? ? Success(player) : Failure(:player_required)
    end

    def open_trades(player)
      Trade.in_progress.where(proposer_id: player.id).or(Trade.in_progress.where(recipient_id: player.id))
    end

    # The player's open trades, locked, once every party's bank lock is held.
    def lock_open_trades(player)
      held = []
      loop do
        missing = ([ player.id ] + open_trades(player).pluck(:proposer_id, :recipient_id).flatten).uniq - held
        break if missing.empty?

        TradeLocks.players(*missing)
        held.concat(missing)
      end
      open_trades(player).order(:id).lock.to_a
    end

    # Lowers `reserved` by every offer of the trades, one proposer at a time
    # in ascending id, their holdings locked by card-season.
    def release_offers(trades, now)
      proposers = trades.to_h { |trade| [ trade.id, trade.proposer_id ] }
      lines = TradeItem.where(trade_id: proposers.keys, side: "offer").pluck(:trade_id, :card_season_id, :quantity)
      lines.group_by { |trade_id, _, _| proposers.fetch(trade_id) }.sort.each do |proposer_id, offered|
        offer = offered.each_with_object(Hash.new(0)) { |(_, card_season_id, quantity), sum| sum[card_season_id] += quantity }
        release(offer, TradeLocks.holdings(proposer_id, offer.keys), now)
      end
    end
  end
end

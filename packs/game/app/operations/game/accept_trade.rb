module Game
  # The friend accepts an open trade (CAP-11, AD-6, AD-8, AD-26): both sides
  # are swapped at once, in one transaction, or nothing moves. Under the bank
  # locks of both players in ascending player id (AD-10), then the trade row,
  # then every holding either player gives or gains, by ascending player then
  # card-season:
  #
  # 1. the player is the recipient (whose turn it is): Failure(:not_allowed);
  # 2. the trade is open: Failure(:trade_not_open);
  # 3. it is not past its expiry: Failure(:trade_expired) (the expiry job
  #    closes it);
  # 4. the two are still friends and the proposer is not banned:
  #    Failure(:not_friends);
  # 5. the requested cards are still free on the recipient's side, each line
  #    at most `quantity - reserved`: Failure(:requested_cards_unavailable);
  # 6. per player and card-season the net change is applied: the proposer
  #    gives the offer (its reservation released) and gains the request, the
  #    recipient gives the request and gains the offer; a holding whose
  #    quantity rises is marked gained now (`last_gained_at`, its NOUVEAU
  #    tag), one that falls to zero stays as a row of zero copies;
  # 7. the trade closes as `accepted` and Game::TradeAccepted is published.
  #
  #   Game::AcceptTrade.new.call(player:, trade_id:)
  #   # => Success(trade) | Failure(:player_required) | Failure(:trade_not_found) | Failure(:not_allowed)
  #   #    | Failure(:trade_not_open) | Failure(:trade_expired) | Failure(:not_friends)
  #   #    | Failure(:requested_cards_unavailable)
  class AcceptTrade < Operation
    include TradeSteps

    def call(player:, trade_id:)
      player = step require_player(player)
      trade = step find_trade(player, trade_id)
      step turn(trade, player, :recipient_id)

      transaction do
        TradeLocks.players(trade.proposer_id, trade.recipient_id)
        trade = Trade.lock.find(trade.id)
        step turn(trade, player, :recipient_id)
        step still_open(trade)
        now = Time.current
        step not_expired(trade, now)
        step friends(player, Accounts::Player.find(trade.proposer_id))
        offer = side_of(trade, "offer")
        request = side_of(trade, "request")
        holdings = lock_holdings(trade, offer, request)
        step requested_free(request, holdings.fetch(trade.recipient_id))
        move(trade.proposer_id, holdings.fetch(trade.proposer_id), given: offer, gained: request, released: offer, now:)
        move(trade.recipient_id, holdings.fetch(trade.recipient_id), given: request, gained: offer, released: {}, now:)
        trade.update!(status: "accepted", closed_at: now)
        step publish(TradeAccepted.new(data: { trade_id: trade.id, proposer_id: trade.proposer_id, recipient_id: trade.recipient_id }),
          stream_name: stream_name(trade.proposer_id))
        trade
      end
    end

    private

    # Both players' holdings of every card either side names, locked by
    # ascending player then card-season: { player_id => { card_season_id => Holding } }.
    def lock_holdings(trade, offer, request)
      cards = (offer.keys | request.keys).sort
      [ trade.low_player_id, trade.high_player_id ].to_h { |player_id| [ player_id, TradeLocks.holdings(player_id, cards) ] }
    end

    def requested_free(request, holdings)
      free = request.all? { |card_season_id, quantity| (holding = holdings[card_season_id]) && quantity <= holding.quantity - holding.reserved }
      free ? Success() : Failure(:requested_cards_unavailable)
    end

    # One player's side of the swap, by card-season: the net change of
    # copies, the reservation released, and the gain time where copies rise.
    # A card the player gains without holding a row yet gets one.
    def move(player_id, holdings, given:, gained:, released:, now:)
      (given.keys | gained.keys).sort.each do |card_season_id|
        net = gained.fetch(card_season_id, 0) - given.fetch(card_season_id, 0)
        unreserve = released.fetch(card_season_id, 0)
        holding = holdings[card_season_id]
        if holding.nil?
          Holding.insert_all!([ { player_id:, card_season_id:, quantity: net, reserved: 0, last_gained_at: now, created_at: now, updated_at: now } ],
            record_timestamps: false)
        elsif net.positive?
          Holding.where(id: holding.id).update_all([ "quantity = quantity + ?, reserved = reserved - ?, last_gained_at = ?, updated_at = ?", net, unreserve, now, now ])
        else
          Holding.where(id: holding.id).update_all([ "quantity = quantity + ?, reserved = reserved - ?, updated_at = ?", net, unreserve, now ])
        end
      end
    end
  end
end

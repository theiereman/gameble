module Game
  class CounterTrade < Operation
    include TradeSteps

    def call(player:, trade_id:, offer:, request:)
      player = step require_player(player)
      offer = step normalise(offer, :invalid_offer)
      request = step normalise(request, :invalid_request)
      step known_cards(request)
      trade = step find_trade(player, trade_id)
      step turn(trade, player, :recipient_id)

      transaction do
        trade = lock_trade(trade)
        step turn(trade, player, :recipient_id)
        step still_open(trade)
        now = Time.current
        step not_expired(trade, now)
        other_id = trade.proposer_id
        step friends(player, Accounts::Player.find(other_id))
        step requestable(request, other_id)
        previous = side_of(trade, "offer")
        holdings = lock_holdings(other_id => previous.keys, player.id => offer.keys)
        step enough_copies(offer, holdings.fetch(player.id))
        release(previous, holdings.fetch(other_id), now)
        TradeItem.where(trade_id: trade.id).delete_all
        create_items(trade, offer, request, now)
        reserve(offer, holdings.fetch(player.id), now)
        trade.update!(proposer_id: player.id, recipient_id: other_id, proposed_at: now, expires_at: now + Trade::LIFETIME)
        step publish(TradeCountered.new(data: { trade_id: trade.id, proposer_id: player.id, recipient_id: other_id }),
          stream_name: stream_name(player.id))
        trade
      end
    end

    private

    def lock_holdings(cards_by_player)
      cards_by_player.sort.to_h { |player_id, cards| [ player_id, TradeLocks.holdings(player_id, cards) ] }
    end
  end
end

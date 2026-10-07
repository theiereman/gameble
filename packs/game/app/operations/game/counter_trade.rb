module Game
  # The friend answers an open trade with a counter-proposal (CAP-11, AD-6,
  # AD-8): a new offer (their own cards) and a new request (the proposer's),
  # each a hash of card-season id => quantity, one to four different cards
  # per side, as in Game::ProposeTrade. The trade keeps its row and the turn
  # passes: the counterer becomes the proposer, the other the recipient, and
  # the 7 days restart from the counter. Under the bank locks of both players
  # in ascending player id (AD-10), then the trade row, then the holdings of
  # the previous and the new offer by ascending player then card-season:
  #
  # 1. the player is the recipient (whose turn it is): Failure(:not_allowed);
  # 2. the trade is open and not past its expiry: Failure(:trade_not_open),
  #    Failure(:trade_expired);
  # 3. the two are still friends and the proposer is not banned:
  #    Failure(:not_friends);
  # 4. each line of the new offer is at most the counterer's free copies
  #    (`quantity - reserved`): Failure(:insufficient_copies), nothing changed;
  # 5. the previous offer is released, the items replaced, the new offer
  #    reserved, the roles swapped and `proposed_at`/`expires_at` restarted,
  #    and Game::TradeCountered is published.
  #
  #   Game::CounterTrade.new.call(player:, trade_id:, offer: { 40 => 1 }, request: { 12 => 1 })
  #   # => Success(trade) | Failure(:player_required) | Failure(:invalid_offer) | Failure(:invalid_request)
  #   #    | Failure(:trade_not_found) | Failure(:not_allowed) | Failure(:trade_not_open)
  #   #    | Failure(:trade_expired) | Failure(:not_friends) | Failure(:insufficient_copies)
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
        TradeLocks.players(trade.proposer_id, trade.recipient_id)
        trade = Trade.lock.find(trade.id)
        step turn(trade, player, :recipient_id)
        step still_open(trade)
        now = Time.current
        step not_expired(trade, now)
        other_id = trade.proposer_id
        step friends(player, Accounts::Player.find(other_id))
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

    # The given cards of each player locked by ascending player then
    # card-season: { player_id => { card_season_id => Holding } }.
    def lock_holdings(cards_by_player)
      cards_by_player.sort.to_h { |player_id, cards| [ player_id, TradeLocks.holdings(player_id, cards) ] }
    end
  end
end

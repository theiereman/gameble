module Game
  class ProposeTrade < Operation
    include TradeSteps

    def call(player:, recipient:, offer:, request:)
      player = step require_player(player)
      offer = step normalise_offer(offer)
      request = step normalise_request(request)
      step known_cards(request)
      step other_player(player, recipient)

      transaction do
        TradeLocks.players(player.id, recipient.id)
        now = Time.current
        step not_already_sent(player, recipient, { "offer" => offer, "request" => request }, now)
        step friends(player, recipient)
        step requestable(request, recipient.id)
        holdings = TradeLocks.holdings(player.id, offer.keys)
        step enough_copies(offer, holdings)
        trade = create_trade(player, recipient, now)
        create_items(trade, offer, request, now)
        reserve(offer, holdings, now)
        step publish(TradeProposed.new(data: { trade_id: trade.id, proposer_id: player.id, recipient_id: recipient.id }),
          stream_name: stream_name(player.id))
        trade
      end
    end

    private

    def other_player(player, recipient)
      recipient.is_a?(Accounts::Player) && recipient.persisted? && recipient.id != player.id ? Success() : Failure(:not_friends)
    end

    def not_already_sent(player, recipient, terms, now)
      sent = Trade.in_progress.where(proposer_id: player.id, recipient_id: recipient.id)
        .where(Trade.arel_table[:expires_at].gt(now)).pluck(:id)
      sent_terms(sent).value?(terms) ? Failure(:trade_already_sent) : Success()
    end

    def sent_terms(trade_ids)
      blank = trade_ids.to_h { |trade_id| [ trade_id, { "offer" => {}, "request" => {} } ] }
      TradeItem.where(trade_id: trade_ids).order(:card_season_id).pluck(:trade_id, :side, :card_season_id, :quantity)
        .each_with_object(blank) { |(trade_id, side, card_season_id, quantity), terms| terms[trade_id][side][card_season_id] = quantity }
    end

    def pair(player, recipient)
      low, high = [ player.id, recipient.id ].minmax
      { low_player_id: low, high_player_id: high }
    end

    def create_trade(player, recipient, now)
      Trade.create!(**pair(player, recipient), proposer_id: player.id, recipient_id: recipient.id,
        status: "open", proposed_at: now, expires_at: now + Trade::LIFETIME)
    end
  end
end

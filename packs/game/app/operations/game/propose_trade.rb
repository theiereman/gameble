module Game
  class ProposeTrade < Operation
    include TradeSteps

    def call(player:, recipient:, offer:, request:)
      player = step require_player(player)
      offer = step normalise(offer, :invalid_offer)
      request = step normalise(request, :invalid_request)
      step known_cards(request)
      step other_player(player, recipient)

      transaction do
        TradeLocks.players(player.id, recipient.id)
        step friends(player, recipient)
        now = Time.current
        expire_due_trade(player, recipient, now)
        step no_open_trade(player, recipient)
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
    rescue ActiveRecord::RecordNotUnique => error
      raise unless error.message.include?("one_open_per_pair")

      Failure(:trade_already_open)
    end

    private

    def other_player(player, recipient)
      recipient.is_a?(Accounts::Player) && recipient.persisted? && recipient.id != player.id ? Success() : Failure(:not_friends)
    end

    def expire_due_trade(player, recipient, now)
      low, high = [ player.id, recipient.id ].minmax
      due = Trade.due(now).find_by(low_player_id: low, high_player_id: high) or return

      ExpireTrade.new.call(player: Accounts::Player.find(due.proposer_id), trade_id: due.id)
    end

    def no_open_trade(player, recipient)
      low, high = [ player.id, recipient.id ].minmax
      Trade.in_progress.exists?(low_player_id: low, high_player_id: high) ? Failure(:trade_already_open) : Success()
    end

    def create_trade(player, recipient, now)
      low, high = [ player.id, recipient.id ].minmax
      Trade.create!(low_player_id: low, high_player_id: high, proposer_id: player.id, recipient_id: recipient.id,
        status: "open", proposed_at: now, expires_at: now + Trade::LIFETIME)
    end
  end
end

module Game
  class AcceptTrade < Operation
    include TradeSteps

    def call(player:, trade_id:, revision:)
      player = step require_player(player)
      trade = step find_trade(player, trade_id)
      step turn(trade, player, :recipient_id)

      transaction do
        trade = lock_trade(trade)
        season = Catalog::PublishedSeason.call
        step turn(trade, player, :recipient_id)
        step still_open(trade)
        step current_terms(trade, revision)
        now = Time.current
        step not_expired(trade, now)
        step friends(player, Accounts::Player.find(trade.proposer_id))
        offer = side_of(trade, "offer")
        request = side_of(trade, "request")
        step no_empty_side(offer, request)
        holdings = lock_holdings(trade, offer, request)
        step enough_copies(request, holdings.fetch(trade.recipient_id), :requested_cards_unavailable)
        move(trade.proposer_id, holdings.fetch(trade.proposer_id), given: offer, gained: request, released: offer, now:)
        move(trade.recipient_id, holdings.fetch(trade.recipient_id), given: request, gained: offer, released: {}, now:)
        ShowcaseEntry.remove_unheld(trade.proposer_id, offer.keys)
        ShowcaseEntry.remove_unheld(trade.recipient_id, request.keys)
        reached = tiers_reached(trade, offer, request, season, now)
        trade.update!(status: "accepted", closed_at: now)
        step publish(TradeAccepted.new(data: { trade_id: trade.id, proposer_id: trade.proposer_id, recipient_id: trade.recipient_id }),
          stream_name: stream_name(trade.proposer_id))
        reached.each { |player_id, tiers| step publish_tiers(player_id, tiers) }
        trade
      end
    end

    private

    def no_empty_side(offer, request)
      offer.empty? || request.empty? ? Failure(:trade_side_empty) : Success()
    end

    def lock_holdings(trade, offer, request)
      cards = (offer.keys | request.keys).sort
      [ trade.low_player_id, trade.high_player_id ].to_h { |player_id| [ player_id, TradeLocks.holdings(player_id, cards) ] }
    end

    def tiers_reached(trade, offer, request, season, now)
      return {} if season.nil?

      gained = { trade.proposer_id => request.keys, trade.recipient_id => offer.keys }
      [ trade.low_player_id, trade.high_player_id ].to_h do |player_id|
        [ player_id, SetTier.record(player_id:, card_season_ids: gained.fetch(player_id), season_id: season.id, reached_by: "trade", pack_id: nil, now:) ]
      end
    end

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

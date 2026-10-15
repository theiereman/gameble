module Game
  module TradeSteps
    private

    def normalise_offer(offer)
      normalise(offer, :invalid_offer, fewest: 0)
    end

    def normalise_request(request)
      normalise(request, :invalid_request, fewest: 1)
    end

    def normalise(side, code, fewest:)
      return Failure(code) unless side.is_a?(Hash) && side.size.between?(fewest, TradeItem::MAX_CARDS_PER_SIDE)

      lines = side.to_h { |id, quantity| [ integer(id), integer(quantity) ] }
      return Failure(code) unless lines.size == side.size && lines.all? { |id, quantity| id&.positive? && quantity&.between?(1, TradeItem::MAX_QUANTITY) }

      Success(lines.sort.to_h)
    end

    def integer(value)
      value.is_a?(Integer) ? value : (Integer(value, 10, exception: false) if value.is_a?(String))
    end

    def known_cards(request)
      Catalog::CardSeason.where(id: request.keys).count == request.size ? Success() : Failure(:invalid_request)
    end

    def requestable(request, holder_id)
      owned = Holding.where(player_id: holder_id, card_season_id: request.keys).pluck(:card_season_id, :quantity).to_h
      request.all? { |card_season_id, quantity| quantity <= owned.fetch(card_season_id, 0) } ? Success() : Failure(:request_exceeds_holdings)
    end

    def friends(player, other)
      current = Accounts::Player.where(id: [ player.id, other.id ]).index_by(&:id)
      fresh_other = current[other.id]
      return Failure(:not_friends) unless fresh_other && !fresh_other.removed? && FriendshipBetween.call(player, fresh_other)

      if !Visibility.open_to_friends?(current[player.id]) then Failure(:own_profile_private)
      elsif !Visibility.open_to_friends?(fresh_other) then Failure(:friend_profile_private)
      else Success()
      end
    end

    def find_trade(player, trade_id)
      trade = Trade.find_by(id: trade_id)
      trade && [ trade.proposer_id, trade.recipient_id ].include?(player.id) ? Success(trade) : Failure(:trade_not_found)
    end

    def lock_trade(trade)
      TradeLocks.players(trade.proposer_id, trade.recipient_id)
      Trade.lock.find(trade.id)
    end

    def turn(trade, player, role)
      trade.public_send(role) == player.id ? Success() : Failure(:not_allowed)
    end

    def still_open(trade)
      trade.open? ? Success() : Failure(:trade_not_open)
    end

    def current_terms(trade, revision)
      trade.revision == revision ? Success() : Failure(:trade_changed)
    end

    def not_expired(trade, now)
      trade.expired?(now) ? Failure(:trade_expired) : Success()
    end

    def enough_copies(lines, holdings, code = :insufficient_copies)
      free = lines.all? { |card_season_id, quantity| (holding = holdings[card_season_id]) && quantity <= holding.quantity - holding.reserved }
      free ? Success() : Failure(code)
    end

    def side_of(trade, side)
      TradeItem.where(trade_id: trade.id, side:).order(:card_season_id).pluck(:card_season_id, :quantity).to_h
    end

    def create_items(trade, offer, request, now)
      rows = { "offer" => offer, "request" => request }.flat_map do |side, lines|
        lines.map { |card_season_id, quantity| { trade_id: trade.id, side:, card_season_id:, quantity:, created_at: now, updated_at: now } }
      end
      TradeItem.insert_all!(rows)
    end

    def reserve(offer, holdings, now)
      shift_reserved(offer, holdings, now, 1)
    end

    def release(offer, holdings, now)
      shift_reserved(offer.slice(*holdings.keys), holdings, now, -1)
    end

    def shift_reserved(offer, holdings, now, sign)
      offer.sort.each do |card_season_id, quantity|
        Holding.where(id: holdings.fetch(card_season_id).id).update_all([ "reserved = reserved + ?, updated_at = ?", sign * quantity, now ])
      end
    end
  end
end

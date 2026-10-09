module Game
  module TradeSteps
    private

    def normalise(side, code)
      return Failure(code) unless side.is_a?(Hash) && side.size.between?(1, TradeItem::MAX_CARDS_PER_SIDE)

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

    def friends(player, other)
      !other.removed? && FriendshipBetween.call(player, other) ? Success() : Failure(:not_friends)
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

    def not_expired(trade, now)
      trade.expired?(now) ? Failure(:trade_expired) : Success()
    end

    def same_terms(trade, seen)
      trade.proposed_at == seen_at(seen) ? Success() : Failure(:trade_changed)
    end

    def seen_at(seen)
      return seen if seen.is_a?(Time)

      Time.iso8601(seen) if seen.is_a?(String)
    rescue ArgumentError
      nil
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

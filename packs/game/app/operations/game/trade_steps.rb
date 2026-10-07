module Game
  # The steps the trade operations share (AD-6, AD-8): reading and checking
  # a side, the parties of a trade, and reserving or releasing an offer on
  # holdings already locked (Game::TradeLocks). Mixed into the trade
  # operations; every method returning a Result is meant for `step`.
  module TradeSteps
    private

    # { card_season_id => quantity } with integer ids and positive integer
    # quantities, one to four cards, sorted by card-season.
    def normalise(side, code)
      return Failure(code) unless side.is_a?(Hash) && side.size.between?(1, TradeItem::MAX_CARDS_PER_SIDE)

      lines = side.to_h { |id, quantity| [ integer(id), integer(quantity) ] }
      return Failure(code) unless lines.size == side.size && lines.all? { |id, quantity| id&.positive? && quantity&.between?(1, TradeItem::MAX_QUANTITY) }

      Success(lines.sort.to_h)
    end

    def integer(value)
      value.is_a?(Integer) ? value : (Integer(value, 10, exception: false) if value.is_a?(String))
    end

    # The requested cards exist in the catalogue.
    def known_cards(request)
      Catalog::CardSeason.where(id: request.keys).count == request.size ? Success() : Failure(:invalid_request)
    end

    # The two are friends and the other is not banned (AD-8).
    def friends(player, other)
      low, high = [ player.id, other.id ].minmax
      friendly = !other.banned? && Friendship.exists?(low_player_id: low, high_player_id: high)
      friendly ? Success() : Failure(:not_friends)
    end

    # The trade, when the player is one of its parties: Failure(:trade_not_found)
    # otherwise. Read without a lock: the parties of a trade never change, only
    # which of them proposes (`turn` checks it again under the lock).
    def find_trade(player, trade_id)
      trade = Trade.find_by(id: trade_id)
      trade && [ trade.proposer_id, trade.recipient_id ].include?(player.id) ? Success(trade) : Failure(:trade_not_found)
    end

    # The player holds `role` (:proposer_id or :recipient_id) in the trade:
    # Failure(:not_allowed) otherwise.
    def turn(trade, player, role)
      trade.public_send(role) == player.id ? Success() : Failure(:not_allowed)
    end

    def still_open(trade)
      trade.open? ? Success() : Failure(:trade_not_open)
    end

    def not_expired(trade, now)
      trade.expired?(now) ? Failure(:trade_expired) : Success()
    end

    # Each offered quantity is at most the free copies (`quantity - reserved`)
    # of the locked holdings.
    def enough_copies(offer, holdings)
      free = offer.all? { |card_season_id, quantity| (holding = holdings[card_season_id]) && quantity <= holding.quantity - holding.reserved }
      free ? Success() : Failure(:insufficient_copies)
    end

    # A side of a stored trade, { card_season_id => quantity }, by card-season.
    def side_of(trade, side)
      TradeItem.where(trade_id: trade.id, side:).order(:card_season_id).pluck(:card_season_id, :quantity).to_h
    end

    def create_items(trade, offer, request, now)
      rows = { "offer" => offer, "request" => request }.flat_map do |side, lines|
        lines.map { |card_season_id, quantity| { trade_id: trade.id, side:, card_season_id:, quantity:, created_at: now, updated_at: now } }
      end
      TradeItem.insert_all!(rows)
    end

    # Raises `reserved` by the offer on the locked holdings, by card-season.
    def reserve(offer, holdings, now)
      shift_reserved(offer, holdings, now, 1)
    end

    # Lowers `reserved` by the offer on the locked holdings, by card-season.
    def release(offer, holdings, now)
      shift_reserved(offer, holdings, now, -1)
    end

    def shift_reserved(offer, holdings, now, sign)
      offer.sort.each do |card_season_id, quantity|
        Holding.where(id: holdings.fetch(card_season_id).id).update_all([ "reserved = reserved + ?, updated_at = ?", sign * quantity, now ])
      end
    end
  end
end

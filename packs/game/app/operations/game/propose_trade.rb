module Game
  # A player proposes a trade to a friend (CAP-11, AD-6, AD-8): an offer and
  # a request, each a hash of card-season id => quantity, one to four
  # different cards per side. Under the bank locks of both players in
  # ascending player id (AD-10):
  #
  # 1. the two are friends (Game::Friendship): Failure(:not_friends), also
  #    for oneself, a banned or an unknown player;
  # 2. they have no open trade, whoever proposed it: Failure(:trade_already_open)
  #    (the partial unique index is the database's guarantee behind it);
  # 3. the proposer's holdings of the offered cards are locked in ascending
  #    card-season and each offered quantity must be at most
  #    `quantity - reserved`: Failure(:insufficient_copies), nothing reserved;
  # 4. the trade and its items are inserted, `reserved` is raised by exactly
  #    the offered quantities, and Game::TradeProposed is published.
  #
  # The requested cards must exist in the catalogue but are neither owned
  # nor reserved: acceptance checks them free. The trade expires 7 days
  # after `now`.
  #
  #   Game::ProposeTrade.new.call(player:, recipient:, offer: { 12 => 2 }, request: { 40 => 1 })
  #   # => Success(trade) | Failure(:player_required) | Failure(:not_friends) | Failure(:invalid_offer)
  #   #    | Failure(:invalid_request) | Failure(:trade_already_open) | Failure(:insufficient_copies)
  class ProposeTrade < Operation
    def call(player:, recipient:, offer:, request:)
      player = step require_player(player)
      offer = step normalise(offer, :invalid_offer)
      request = step normalise(request, :invalid_request)
      step known_cards(request)
      step other_player(player, recipient)

      transaction do
        TradeLocks.players(player.id, recipient.id)
        step friends(player, recipient)
        step no_open_trade(player, recipient)
        holdings = TradeLocks.holdings(player.id, offer.keys)
        step enough_copies(offer, holdings)
        now = Time.current
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

    # { card_season_id => quantity } with integer ids and positive integer
    # quantities, one to four cards.
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

    def other_player(player, recipient)
      recipient.is_a?(Accounts::Player) && recipient.persisted? && recipient.id != player.id ? Success() : Failure(:not_friends)
    end

    def friends(player, recipient)
      low, high = [ player.id, recipient.id ].minmax
      friendly = !recipient.banned? && Friendship.exists?(low_player_id: low, high_player_id: high)
      friendly ? Success() : Failure(:not_friends)
    end

    def no_open_trade(player, recipient)
      low, high = [ player.id, recipient.id ].minmax
      Trade.in_progress.exists?(low_player_id: low, high_player_id: high) ? Failure(:trade_already_open) : Success()
    end

    def enough_copies(offer, holdings)
      free = offer.all? { |card_season_id, quantity| (holding = holdings[card_season_id]) && quantity <= holding.quantity - holding.reserved }
      free ? Success() : Failure(:insufficient_copies)
    end

    def create_trade(player, recipient, now)
      low, high = [ player.id, recipient.id ].minmax
      Trade.create!(low_player_id: low, high_player_id: high, proposer_id: player.id, recipient_id: recipient.id,
        status: "open", proposed_at: now, expires_at: now + Trade::LIFETIME)
    end

    def create_items(trade, offer, request, now)
      rows = { "offer" => offer, "request" => request }.flat_map do |side, lines|
        lines.map { |card_season_id, quantity| { trade_id: trade.id, side:, card_season_id:, quantity:, created_at: now, updated_at: now } }
      end
      TradeItem.insert_all!(rows)
    end

    def reserve(offer, holdings, now)
      offer.each do |card_season_id, quantity|
        Holding.where(id: holdings.fetch(card_season_id).id).update_all([ "reserved = reserved + ?, updated_at = ?", quantity, now ])
      end
    end
  end
end

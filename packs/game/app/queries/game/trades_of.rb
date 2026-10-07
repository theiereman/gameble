module Game
  # A player's trades as the trades screen shows them (CAP-11, AD-8;
  # EXPERIENCE.md, Trade list row, Trade board), each seen from the player's
  # side: the friend, what each of them gives, the state and its time. Trades
  # whose other party is banned are left out (AD-13).
  #
  # States: `:yours` (open, the player's turn), `:theirs` (open, the
  # friend's turn), `:concluded` (accepted) and `:closed` (declined,
  # cancelled or expired). An open trade past its expiry can no longer be
  # answered: it reads as closed and expired from then on, before
  # Game::ExpireTradesJob closes it (its `ended_at` is the expiry).
  #
  # `friend_side` is what the friend gives (or gave, or offered), `own_side`
  # what the player gives, each a list of Line by card-season. `id` is for
  # the operations, server side: never put it in a page (AD-15), the token
  # addresses the trade.
  #
  #   Game::TradesOf.call(player)                  # => Result(yours: [Row, …], theirs: […], recent: […])
  #   Game::TradesOf.find(player, token)           # => Row | nil
  module TradesOf
    # How long a finished trade stays in "TERMINÉS RÉCEMMENT", and how many.
    RECENT = 14.days
    RECENT_LIMIT = 20

    Line = Data.define(:card_season_id, :quantity)

    Row = Data.define(:id, :token, :friend, :state, :outcome, :friend_side, :own_side, :expires_at, :ended_at) do
      def open? = %i[yours theirs].include?(state)
      def card_season_ids = (friend_side + own_side).map(&:card_season_id).uniq
    end

    Result = Data.define(:yours, :theirs, :recent) do
      def empty? = yours.empty? && theirs.empty? && recent.empty?
      # The first trade, in the order of the list.
      def first = yours.first || theirs.first || recent.first
    end

    def self.call(player, now: Time.current)
      return Result.new(yours: [], theirs: [], recent: []) unless player

      since = now - RECENT
      trades = of(player).where("status = 'open' OR closed_at >= ?", since).to_a
      rows = rows(player, trades, now)
      recent = rows.reject(&:open?).select { |row| row.ended_at >= since }.sort_by { |row| [ -row.ended_at.to_f, -row.id ] }
      Result.new(
        yours: rows.select { |row| row.state == :yours }.sort_by { |row| [ row.expires_at, row.id ] },
        theirs: rows.select { |row| row.state == :theirs }.sort_by { |row| [ row.expires_at, row.id ] },
        recent: recent.first(RECENT_LIMIT)
      )
    end

    # One of the player's trades by its token, of any age; nil for a visitor,
    # an unknown token, someone else's trade, or one whose other party is
    # banned.
    def self.find(player, token, now: Time.current)
      return unless player && token.is_a?(String)

      rows(player, of(player).where(token:).to_a, now).first
    end

    def self.of(player)
      Trade.where(proposer_id: player.id).or(Trade.where(recipient_id: player.id))
    end
    private_class_method :of

    def self.rows(player, trades, now)
      return [] if trades.empty?

      items = TradeItem.where(trade_id: trades.map(&:id)).order(:card_season_id).group_by(&:trade_id)
      others = trades.map { |trade| other_id(trade, player) }.uniq
      friends = Accounts::Player.where(id: others, banned_at: nil).index_by(&:id)

      trades.filter_map do |trade|
        friend = friends[other_id(trade, player)]
        next unless friend

        lines = items.fetch(trade.id, []).group_by(&:side).transform_values { |side| side.map { Line.new(card_season_id: it.card_season_id, quantity: it.quantity) } }
        offer = lines.fetch("offer", [])
        request = lines.fetch("request", [])
        proposer = trade.proposer_id == player.id
        state, outcome, ended_at = state_of(trade, player, now)
        Row.new(id: trade.id, token: trade.token, friend:, state:, outcome:,
          friend_side: proposer ? request : offer, own_side: proposer ? offer : request,
          expires_at: trade.expires_at, ended_at:)
      end
    end
    private_class_method :rows

    def self.other_id(trade, player)
      trade.proposer_id == player.id ? trade.recipient_id : trade.proposer_id
    end
    private_class_method :other_id

    # [state, outcome, ended_at]
    def self.state_of(trade, player, now)
      if trade.open?
        return [ :closed, "expired", trade.expires_at ] if trade.expired?(now)

        [ trade.recipient_id == player.id ? :yours : :theirs, nil, nil ]
      elsif trade.status == "accepted"
        [ :concluded, "accepted", trade.closed_at ]
      else
        [ :closed, trade.status, trade.closed_at ]
      end
    end
    private_class_method :state_of
  end
end

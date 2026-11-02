module Game
  module TradeSuggestions
    MAX_SUGGESTIONS = 3

    Line = Data.define(:card_season_id, :card_id, :goal_positions) do
      def quantity = 1
    end

    Suggestion = Data.define(:friend, :lines, :own_lines) do
      def player = friend.player
      def card_season_ids = lines.map(&:card_season_id)
      def own_card_season_ids = own_lines.map(&:card_season_id)
      def mutual? = own_lines.any?
      def served_goals = lines.flat_map(&:goal_positions).tally.sort.to_h
    end

    Result = Data.define(:goals, :suggestions) do
      def empty? = suggestions.empty?
      def card_season_ids = suggestions.flat_map { it.card_season_ids + it.own_card_season_ids }.uniq
    end

    Edition = Data.define(:card_season_id, :free, :rarity, :season_number, :slug)
    Spare = Data.define(:card_id, :edition, :goal_positions) do
      def rank = [ goal_positions.min, -edition.rarity, edition.slug ]
    end

    NONE = Result.new(goals: [], suggestions: []).freeze

    FREE_EDITIONS = <<~SQL.squish.freeze
      SELECT game_holdings.player_id, catalog_card_seasons.card_id, game_holdings.card_season_id,
             game_holdings.quantity - game_holdings.reserved AS free, COALESCE(catalog_card_seasons.rarity, 0) AS rarity,
             catalog_seasons.number, catalog_cards.slug
        FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
        JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id
        JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id
       WHERE game_holdings.player_id IN (:friend_ids) AND game_holdings.quantity > game_holdings.reserved
         AND (:all_cards OR catalog_card_seasons.card_id IN (:card_ids))
    SQL

    ON_PLAYER_SIDE = <<~SQL.squish.freeze
      SELECT DISTINCT CASE WHEN game_trades.proposer_id = :player_id THEN game_trades.recipient_id ELSE game_trades.proposer_id END,
             catalog_card_seasons.card_id
        FROM game_trade_items
        JOIN game_trades ON game_trades.id = game_trade_items.trade_id
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_trade_items.card_season_id
       WHERE game_trades.status = 'open' AND game_trades.expires_at > :now
         AND ((game_trades.proposer_id = :player_id AND game_trades.recipient_id IN (:friend_ids) AND game_trade_items.side = 'offer')
           OR (game_trades.recipient_id = :player_id AND game_trades.proposer_id IN (:friend_ids) AND game_trade_items.side = 'request'))
    SQL

    IN_OPEN_TRADES = <<~SQL.squish.freeze
      SELECT DISTINCT CASE WHEN game_trades.proposer_id = :player_id THEN game_trades.recipient_id ELSE game_trades.proposer_id END,
             catalog_card_seasons.card_id
        FROM game_trade_items
        JOIN game_trades ON game_trades.id = game_trade_items.trade_id
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_trade_items.card_season_id
       WHERE game_trades.status = 'open' AND game_trades.expires_at > :now
         AND ((game_trades.proposer_id = :player_id AND game_trades.recipient_id IN (:friend_ids) AND game_trade_items.side = 'request')
           OR (game_trades.recipient_id = :player_id AND game_trades.proposer_id IN (:friend_ids) AND game_trade_items.side = 'offer'))
    SQL

    ON_HOLDER_SIDE = <<~SQL.squish.freeze
      SELECT DISTINCT catalog_card_seasons.card_id
        FROM game_trade_items
        JOIN game_trades ON game_trades.id = game_trade_items.trade_id
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_trade_items.card_season_id
       WHERE game_trades.status = 'open' AND game_trades.expires_at > :now
         AND ((game_trades.proposer_id = :holder_id AND game_trades.recipient_id = :other_id AND game_trade_items.side = 'offer')
           OR (game_trades.proposer_id = :other_id AND game_trades.recipient_id = :holder_id AND game_trade_items.side = 'request'))
    SQL

    CARDS_OF_SEASONS = "SELECT id, card_id FROM catalog_card_seasons WHERE id IN (:card_season_ids)".freeze

    def self.call(player, now: Time.current)
      return NONE unless Visibility.open_to_friends?(player)

      goals = GoalNeeds.call(player)
      wanted = goal_positions_by_card(goals)
      return Result.new(goals:, suggestions: []) if wanted.empty?

      friends = FriendsPresence.call(player, now:).reject { it.state == :private }
      Result.new(goals:, suggestions: suggestions(player, friends, wanted, now))
    end

    def self.goal_positions_by_card(goals)
      goals.each_with_object(Hash.new { |hash, card_id| hash[card_id] = [] }) do |need, wanted|
        need.missing_card_ids.each { wanted[it] << need.position }
      end
    end

    def self.suggestions(player, friends, wanted, now)
      return [] if friends.empty?

      friend_ids = friends.map { it.player.id }
      spares = spares_by_friend(player, friend_ids, wanted, now)
      gives = gives_by_friend(player, spares.keys, now)
      befriended_at = friendship_dates(player)
      ranked = friends.select { spares.key?(it.player.id) }.sort_by do
        [ gives.key?(it.player.id) ? 0 : 1, -spares[it.player.id].size, befriended_at.fetch(it.player.id), it.player.token ]
      end
      fill(ranked, spares, gives)
    end

    def self.fill(ranked, spares, gives)
      placed = Set.new
      given = Set.new
      ranked.each_with_object([]) do |friend, suggestions|
        break suggestions if suggestions.size >= MAX_SUGGESTIONS

        chosen = spares.fetch(friend.player.id).reject { placed.include?(it.card_id) }.first(TradeItem::MAX_CARDS_PER_SIDE)
        next if chosen.empty?

        offered = gives.fetch(friend.player.id, []).reject { given.include?(it.card_id) }.first(TradeItem::MAX_CARDS_PER_SIDE)
        placed.merge(chosen.map(&:card_id))
        given.merge(offered.map(&:card_id))
        suggestions << Suggestion.new(friend:, lines: lines_of(chosen), own_lines: lines_of(offered))
      end
    end

    def self.lines_of(spares)
      spares.map { Line.new(card_season_id: it.edition.card_season_id, card_id: it.card_id, goal_positions: it.goal_positions) }
    end

    # What the player spares that a friend's goals on game sets miss, per friend,
    # ranked on the friend's goals; the lines never carry those goals.
    def self.gives_by_friend(player, friend_ids, now)
      return {} if friend_ids.empty?

      gaps = GameSetGaps.call(friend_ids)
      return {} if gaps.empty?

      spared = free_editions([ player.id ], nil).filter_map { |(_, card_id), editions| (edition = placed_edition(editions)) && [ card_id, edition ] }
      return {} if spared.empty?

      offered = on_player_side(player, friend_ids, now)
      friend_ids.each_with_object({}) do |friend_id, gives|
        missed = gaps.fetch(friend_id, {})
        list = spared.filter_map do |card_id, edition|
          next unless missed.key?(card_id) && !offered.include?([ friend_id, card_id ])

          Spare.new(card_id:, edition:, goal_positions: missed.fetch(card_id).uniq.sort)
        end
        gives[friend_id] = list.sort_by(&:rank).map { it.with(goal_positions: []) } if list.any?
      end
    end

    def self.spares_by_friend(player, friend_ids, wanted, now)
      taken = in_open_trades(player, friend_ids, now)
      spares = Hash.new { |hash, friend_id| hash[friend_id] = [] }
      free_editions(friend_ids, wanted.keys).each do |(friend_id, card_id), editions|
        next if taken.include?([ friend_id, card_id ])

        edition = placed_edition(editions) or next
        spares[friend_id] << Spare.new(card_id:, edition:, goal_positions: wanted.fetch(card_id).uniq.sort)
      end
      spares.to_h { |friend_id, list| [ friend_id, list.sort_by(&:rank) ] }
    end

    def self.still_spared(card_season_ids, holder:, other:, now: Time.current)
      return [] if card_season_ids.empty?

      card_ids = card_ids_of(card_season_ids)
      return [] if card_ids.empty?

      taken = on_holder_side(holder, other, now)
      editions = free_editions([ holder.id ], card_ids.values.uniq)
      card_season_ids.select do |id|
        card_id = card_ids[id.to_i]
        next false if card_id.nil? || taken.include?(card_id)

        spare_editions(editions.fetch([ holder.id, card_id ], [])).any? { it.card_season_id == id.to_i }
      end
    end

    def self.placed_edition(editions)
      spare_editions(editions).max_by { [ it.free, -it.season_number ] }
    end

    def self.spare_editions(editions)
      kept = editions.max_by { [ it.rarity, -it.season_number ] }
      editions.map { it == kept ? it.with(free: it.free - 1) : it }.select { it.free.positive? }
    end

    def self.free_editions(friend_ids, card_ids)
      sql = Holding.sanitize_sql_array([ FREE_EDITIONS, { friend_ids:, card_ids: card_ids || [ 0 ], all_cards: card_ids.nil? } ])
      Holding.connection.select_rows(sql, "Game::TradeSuggestions.free_editions")
        .group_by { |friend_id, card_id| [ friend_id.to_i, card_id.to_i ] }
        .transform_values do |rows|
          rows.map do |_, _, card_season_id, free, rarity, season_number, slug|
            Edition.new(card_season_id: card_season_id.to_i, free: free.to_i, rarity: rarity.to_i, season_number: season_number.to_i, slug:)
          end
        end
    end

    def self.in_open_trades(player, friend_ids, now)
      sql = Trade.sanitize_sql_array([ IN_OPEN_TRADES, { player_id: player.id, friend_ids:, now: } ])
      Trade.connection.select_rows(sql, "Game::TradeSuggestions.in_open_trades").to_set { |friend_id, card_id| [ friend_id.to_i, card_id.to_i ] }
    end

    def self.on_player_side(player, friend_ids, now)
      sql = Trade.sanitize_sql_array([ ON_PLAYER_SIDE, { player_id: player.id, friend_ids:, now: } ])
      Trade.connection.select_rows(sql, "Game::TradeSuggestions.on_player_side").to_set { |friend_id, card_id| [ friend_id.to_i, card_id.to_i ] }
    end

    def self.card_ids_of(card_season_ids)
      sql = Holding.sanitize_sql_array([ CARDS_OF_SEASONS, { card_season_ids: } ])
      Holding.connection.select_rows(sql, "Game::TradeSuggestions.card_ids_of").to_h { |id, card_id| [ id.to_i, card_id.to_i ] }
    end

    def self.on_holder_side(holder, other, now)
      sql = Trade.sanitize_sql_array([ ON_HOLDER_SIDE, { holder_id: holder.id, other_id: other.id, now: } ])
      Trade.connection.select_rows(sql, "Game::TradeSuggestions.on_holder_side").to_set { |(card_id)| card_id.to_i }
    end

    def self.friendship_dates(player)
      Friendship.of(player.id).pluck(:low_player_id, :high_player_id, :created_at)
        .to_h { |low, high, created_at| [ low == player.id ? high : low, created_at ] }
    end

    private_class_method :goal_positions_by_card, :suggestions, :fill, :spares_by_friend, :placed_edition, :free_editions,
      :in_open_trades, :friendship_dates, :lines_of, :gives_by_friend, :on_player_side
    private_class_method :spare_editions, :card_ids_of, :on_holder_side
  end
end

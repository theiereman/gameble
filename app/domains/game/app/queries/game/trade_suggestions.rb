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

    DUPLICATE_COPIES = 2

    Result = Data.define(:goals, :suggestions) do
      def empty? = suggestions.empty?
      def card_season_ids = suggestions.flat_map { it.card_season_ids + it.own_card_season_ids }.uniq
    end

    NONE = Result.new(goals: [], suggestions: []).freeze

    def self.call(player, now: Time.current)
      return NONE unless Visibility.open_to_friends?(player)

      goals = GoalNeeds.call(player)
      wanted = goal_positions_by_card(goals)
      return Result.new(goals:, suggestions: []) if wanted.empty?

      friends = FriendsPresence.call(player, now:).reject { it.state == :private }
      Result.new(goals:, suggestions: suggestions(player, friends, wanted, now))
    end

    def self.still_spared(card_season_ids, holder:, other:, now: Time.current, minimum_copies: 1)
      return [] if card_season_ids.empty?

      card_ids = FreeEditions.card_ids_of(card_season_ids)
      return [] if card_ids.empty?

      taken = OpenTrades.offered_by(holder, [ other.id ], now).to_set { |(_, card_id)| card_id }
      editions = FreeEditions.call([ holder.id ], card_ids.values.uniq)
      card_season_ids.select do |id|
        card_id = card_ids[id.to_i]
        next false if card_id.nil? || taken.include?(card_id)

        held = editions.fetch([ holder.id, card_id ], [])
        FreeEditions.copies(held) >= minimum_copies && FreeEditions.spare(held).any? { it.card_season_id == id.to_i }
      end
    end

    def self.goal_positions_by_card(goals)
      goals.each_with_object(Hash.new { |hash, card_id| hash[card_id] = [] }) do |need, wanted|
        need.missing_card_ids.each { wanted[it] << need.position }
      end
    end

    def self.suggestions(player, friends, wanted, now)
      return [] if friends.empty?

      friend_ids = friends.map { it.player.id }
      declined = DeclinedByFriend.call(player, friend_ids)
      spares = Spares.from_friends(player, friend_ids, wanted, declined, now)
      gives = Spares.from_player(player, spares.keys, declined, now)
      befriended_at = friendship_dates(player)
      ranked = friends.select { spares.key?(it.player.id) }.sort_by do
        [ gives.key?(it.player.id) ? 0 : 1, -spares[it.player.id].size, befriended_at.fetch(it.player.id), it.player.token ]
      end
      fill(ranked, spares, gives).sort_by.with_index { |suggestion, index| [ suggestion.mutual? ? 0 : 1, index ] }.first(MAX_SUGGESTIONS)
    end

    def self.fill(ranked, spares, gives)
      placed = Set.new
      given = Set.new
      served = Set.new
      ranked.each_with_object([]) do |friend, suggestions|
        chosen = spares.fetch(friend.player.id).reject { placed.include?(it.card_id) || it.goal_positions.intersect?(served.to_a) }.first(TradeItem::MAX_CARDS_PER_SIDE)
        next if chosen.empty?

        offered = gives.fetch(friend.player.id, []).reject { given.include?(it.card_id) }.first(TradeItem::MAX_CARDS_PER_SIDE)
        placed.merge(chosen.map(&:card_id))
        served.merge(chosen.flat_map(&:goal_positions))
        given.merge(offered.map(&:card_id))
        suggestions << Suggestion.new(friend:, lines: lines_of(chosen), own_lines: lines_of(offered))
      end
    end

    def self.lines_of(spares)
      spares.map { Line.new(card_season_id: it.edition.card_season_id, card_id: it.card_id, goal_positions: it.goal_positions) }
    end

    def self.friendship_dates(player)
      Friendship.of(player.id).pluck(:low_player_id, :high_player_id, :created_at)
        .to_h { |low, high, created_at| [ low == player.id ? high : low, created_at ] }
    end

    private_class_method :goal_positions_by_card, :suggestions, :fill, :friendship_dates, :lines_of
  end
end

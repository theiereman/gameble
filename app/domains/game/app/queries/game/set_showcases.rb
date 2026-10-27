module Game
  # What a set progress tile shows of a player's sets, for any number of sets
  # in two queries. A set of SMALL_SET cards or fewer shows every member in
  # set order: the player's best edition of a game they hold, the set's own
  # rarity of one they miss. A larger set shows its BEST_SHOWN best held
  # games, the rarest first, and counts the others held. Every set names the
  # game gained in it last, at its best edition.
  #
  #   Game::SetShowcases.call(player, set_ids: [ … ], season:, locale: "fr")
  #   # => { set_id => Showcase(slots: [ Slot(card: CardView, rarity: "epic"), Slot(card: nil, rarity: "rare") ],
  #   #      others: 0, last_gained: LastGained(card: CardView, gained_at: Time)) }
  module SetShowcases
    SMALL_SET = 5
    BEST_SHOWN = 3

    Showcase = Data.define(:slots, :others, :last_gained)
    Slot = Data.define(:card, :rarity) do
      def owned? = !card.nil?
    end
    LastGained = Data.define(:card, :gained_at)
    Member = Data.define(:size, :rarity, :held_id, :held_rarity, :gained_at) do
      def shown_held? = !held_id.nil? && !held_rarity.nil?
    end
    Pick = Data.define(:shown, :others, :latest) do
      def card_ids = [ *shown.filter_map(&:held_id), latest&.held_id ].compact.uniq
    end

    SQL = <<~SQL.squish.freeze
      WITH members AS (
        SELECT memberships.set_id, memberships.position, memberships.id AS membership_id, member.card_id, member.rarity,
               COUNT(*) OVER (PARTITION BY memberships.set_id) AS size
          FROM catalog_set_memberships AS memberships
          JOIN catalog_card_seasons AS member ON member.id = memberships.card_season_id
         WHERE memberships.set_id IN (:set_ids)
      ),
      editions AS (
        SELECT DISTINCT ON (catalog_card_seasons.card_id) catalog_card_seasons.card_id, game_holdings.card_season_id,
               catalog_card_seasons.rarity, MAX(game_holdings.last_gained_at) OVER games AS gained_at
          FROM game_holdings
          JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
         WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > 0
           AND catalog_card_seasons.card_id IN (SELECT members.card_id FROM members)
        WINDOW games AS (PARTITION BY catalog_card_seasons.card_id)
         ORDER BY catalog_card_seasons.card_id, #{HeldGames::EDITION_ORDER}
      )
      SELECT members.set_id, members.size, members.rarity, editions.card_season_id, editions.rarity, editions.gained_at
        FROM members
        LEFT JOIN editions ON editions.card_id = members.card_id
       WHERE editions.card_id IS NOT NULL OR members.size <= :small_set
       ORDER BY members.set_id, members.position, members.membership_id
    SQL

    def self.call(player, set_ids:, season:, locale:)
      return {} if player.nil? || season.nil? || set_ids.empty?

      picks = members_by_set(player, set_ids, season).transform_values { pick(it) }
      views = Catalog::CardViews.call(picks.values.flat_map(&:card_ids), locale:)
      picks.transform_values { showcase(it, views) }
    end

    def self.members_by_set(player, set_ids, season)
      sql = Holding.sanitize_sql_array([ SQL, { player_id: player.id, set_ids: set_ids.uniq, season_id: season.id, small_set: SMALL_SET } ])
      rows = Holding.connection.select_all(sql, "Game::SetShowcases").cast_values
      rows.group_by(&:first).transform_values do |set_rows|
        set_rows.map do |_set_id, size, rarity, held_id, held_rarity, gained_at|
          Member.new(size:, rarity: rarity_name(rarity), held_id:, held_rarity:, gained_at:)
        end
      end
    end

    def self.pick(members)
      held = members.select(&:shown_held?)
      shown = members.first.size <= SMALL_SET ? members.select { it.held_id.nil? || it.shown_held? } : best(held)
      Pick.new(shown:, others: held.size - shown.count(&:held_id), latest: held.select(&:gained_at).max_by(&:gained_at))
    end

    def self.showcase(pick, views)
      slots = pick.shown.filter_map do |member|
        next Slot.new(card: nil, rarity: member.rarity) if member.held_id.nil?

        views[member.held_id]&.then { Slot.new(card: it, rarity: it.rarity) }
      end
      last_gained = pick.latest&.then { |latest| views[latest.held_id]&.then { LastGained.new(card: it, gained_at: latest.gained_at) } }
      Showcase.new(slots:, others: pick.others, last_gained:)
    end

    def self.best(held)
      held.each_with_index.sort_by { |member, index| [ -member.held_rarity, index ] }.first(BEST_SHOWN).map(&:first)
    end

    def self.rarity_name(rarity)
      Catalog::Rarity::TIERS[rarity]&.to_s
    end

    private_class_method :members_by_set, :pick, :showcase, :best, :rarity_name
  end
end

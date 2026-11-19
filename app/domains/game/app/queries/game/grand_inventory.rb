module Game
  class GrandInventory
    SCOPES = %i[all current].freeze
    STATES = %w[found all missing mine].freeze
    DEFAULT_STATE = "all"

    Discovery = Data.define(:card, :player, :discovered_at)

    SetProgress = Data.define(:set_id, :found, :total, :completed_at) do
      def complete? = found == total

      def missing = total - found
    end

    DISCOVERIES = <<~SQL.squish.freeze
      SELECT DISTINCT ON (editions.card_id) editions.card_id, game_first_discoveries.player_id, game_first_discoveries.discovered_at
        FROM game_first_discoveries
        JOIN catalog_card_seasons AS editions ON editions.id = game_first_discoveries.card_season_id
       WHERE editions.card_id IN (SELECT card_id FROM catalog_card_seasons WHERE season_id = :season_id AND rarity IS NOT NULL)
         AND (:all_seasons OR editions.season_id = :season_id)
       ORDER BY editions.card_id, game_first_discoveries.discovered_at, game_first_discoveries.id
    SQL

    CARDS = <<~SQL.squish.freeze
      SELECT card_id, id, rarity FROM catalog_card_seasons WHERE season_id = :season_id AND rarity IS NOT NULL
    SQL

    SET_PROGRESS = <<~SQL.squish.freeze
      SELECT members.set_id, COUNT(inventory.card_id) AS found, COUNT(*) AS total, MAX(inventory.discovered_at) AS last_found
        FROM catalog_set_memberships AS members
        JOIN catalog_card_seasons AS member ON member.id = members.card_season_id
        LEFT JOIN (#{DISCOVERIES}) AS inventory ON inventory.card_id = member.card_id
       WHERE member.season_id = :season_id AND member.rarity IS NOT NULL
         AND (CAST(:set_kind AS varchar) IS NULL OR members.set_id IN (
           SELECT id FROM catalog_sets WHERE season_id = :season_id AND kind = :set_kind AND key = :set_key
         ))
       GROUP BY members.set_id
    SQL

    PUBLISHED_EDITION = <<~SQL.squish.freeze
      JOIN catalog_card_seasons AS editions ON editions.id = game_first_discoveries.card_season_id
      JOIN catalog_card_seasons AS published ON published.card_id = editions.card_id
       AND published.season_id = ? AND published.rarity IS NOT NULL
    SQL

    def self.states(asked, viewer: nil)
      offered = viewer ? STATES : STATES - [ "mine" ]
      chosen = offered & Array(asked).map(&:to_s)
      chosen -= [ DEFAULT_STATE ] if chosen.size > 1
      chosen.presence || [ DEFAULT_STATE ]
    end

    attr_reader :scope, :season

    def initialize(seasons: :all, season: Catalog::PublishedSeason.call, locale: I18n.locale)
      raise ArgumentError, "unknown scope #{seasons.inspect}" unless SCOPES.include?(seasons)

      @scope = seasons
      @season = season
      @locale = locale
    end

    def total = cards.size

    def found_count = found.size

    def found?(card) = found.key?(card_id_of(card))

    def pioneer_of(card) = pioneers_of([ card_id_of(card) ]).values.first

    def pioneers_of(card_ids)
      ids = card_ids.select { found.key?(it) && cards.key?(it) }
      return {} if ids.empty?

      players = Accounts::Player.where(id: ids.map { found[it].first }.uniq).index_by(&:id)
      views = Catalog::CardViews.call(ids.map { cards[it].first }, locale: @locale)
      ids.to_h do |card_id|
        player_id, discovered_at = found[card_id]
        [ card_id, Discovery.new(card: views[cards[card_id].first], player: players[player_id], discovered_at:) ]
      end
    end

    def latest_discovery
      return @latest_discovery if defined?(@latest_discovery)

      player_id, discovered_at, card_season_id = published_discoveries.order(discovered_at: :desc, id: :desc)
        .pick("game_first_discoveries.player_id", "game_first_discoveries.discovered_at", "published.id")
      @latest_discovery = card_season_id && Discovery.new(card: Catalog::CardViews.call([ card_season_id ], locale: @locale)[card_season_id],
        player: Accounts::Player.find_by(id: player_id), discovered_at:)
    end

    def found_since(time)
      return 0 if season.nil?

      published_discoveries.where(discovered_at: time..).count
    end

    def per_rarity
      tally = Catalog::Rarity::TIERS.values.index_with { [ 0, 0 ] }
      cards.each do |card_id, (_card_season_id, rarity)|
        found_total = tally.fetch(rarity)
        found_total[0] += 1 if found.key?(card_id)
        found_total[1] += 1
      end
      tally
    end

    def set_progress(set)
      progress = set_progresses(kind: set.kind, key: set.key).first
      progress ? [ progress.found, progress.total ] : [ 0, 0 ]
    end

    def set_progresses(kind: nil, key: nil)
      return [] if season.nil?

      rows(SET_PROGRESS, set_kind: kind, set_key: key).map do |set_id, found_count, total, last_found|
        SetProgress.new(set_id:, found: found_count, total:, completed_at: (last_found if found_count == total))
      end
    end

    def cards_in_order(relation, states:, viewer: nil)
      relation = relation.joins("LEFT JOIN (#{discoveries_sql}) AS inventory ON inventory.card_id = catalog_card_seasons.card_id")
      chosen = self.class.states(states, viewer:)
      relation = relation.where(chosen.map { "(#{state_condition(it, viewer)})" }.join(" OR ")) unless chosen.include?(DEFAULT_STATE)
      relation.reorder(Arel.sql("inventory.discovered_at DESC NULLS LAST"), :number, :id)
    end

    private
      def state_condition(state, viewer)
        case state
        when "found" then "inventory.card_id IS NOT NULL"
        when "missing" then "inventory.card_id IS NULL"
        when "mine" then FirstDiscovery.sanitize_sql_array([ "inventory.player_id = ?", viewer.id ])
        end
      end

      def card_id_of(card)
        card.is_a?(Integer) ? card : card.try(:card_id) || card.id
      end

      def cards
        @cards ||= rows(CARDS).to_h { |card_id, id, rarity| [ card_id, [ id, Catalog::Rarity::TIERS.fetch(rarity) ] ] }
      end

      def found
        @found ||= rows(DISCOVERIES).to_h { |card_id, player_id, discovered_at| [ card_id, [ player_id, discovered_at ] ] }
      end

      def discoveries_sql
        FirstDiscovery.sanitize_sql_array([ DISCOVERIES, { season_id: season&.id, all_seasons: scope == :all } ])
      end

      def published_discoveries
        FirstDiscovery.joins(FirstDiscovery.sanitize_sql_array([ PUBLISHED_EDITION, season&.id ]))
      end

      def rows(sql, **binds)
        return [] if season.nil?

        query = FirstDiscovery.sanitize_sql_array([ sql, { season_id: season.id, all_seasons: scope == :all, **binds } ])
        FirstDiscovery.connection.select_all(query, "Game::GrandInventory").cast_values
      end
  end
end

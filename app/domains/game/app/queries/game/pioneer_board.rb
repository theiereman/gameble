module Game
  module PioneerBoard
    PAGE_SIZE = 50
    TOP = 3
    PERIODS = %i[week season total].freeze

    Row = Data.define(:rank, :player, :count)
    Place = Data.define(:rank, :count, :page)
    Board = Data.define(:period, :rows, :place)

    def self.period_for(choice, scope)
      return :week if choice == :week

      scope == :current ? :season : :total
    end

    def self.ranked(period, now: Time.current)
      counts = of_period(period, now)
        .where(player_id: Accounts::Player.in_good_standing.select(:id))
        .group(:player_id)
        .select(:player_id, Arel.sql("COUNT(*) AS discoveries"),
          Arel.sql("RANK() OVER (ORDER BY COUNT(*) DESC) AS pioneer_rank"),
          Arel.sql("ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC, MAX(game_first_discoveries.discovered_at), " \
            "game_first_discoveries.player_id) AS pioneer_position"))
      FirstDiscovery.from(counts, :game_first_discoveries).order(:pioneer_position)
    end

    def self.rows(standings)
      players = Accounts::Player.where(id: standings.map(&:player_id)).index_by(&:id)
      standings.map { Row.new(rank: it.pioneer_rank, player: players.fetch(it.player_id), count: it.discoveries) }
    end

    def self.place(viewer, period, now: Time.current)
      standing = viewer && ranked(period, now:).find_by(player_id: viewer.id)
      return unless standing

      Place.new(rank: standing.pioneer_rank, count: standing.discoveries, page: ((standing.pioneer_position - 1) / PAGE_SIZE) + 1)
    end

    def self.board(period, viewer:, now: Time.current)
      Board.new(period:, rows: rows(ranked(period, now:).limit(TOP).to_a), place: place(viewer, period, now:))
    end

    def self.of_period(period, now)
      case period
      when :week then FirstDiscovery.where(discovered_at: now.utc.beginning_of_week(:monday)..)
      when :season then of_season(Catalog::PublishedSeason.call)
      when :total then FirstDiscovery.all
      else raise ArgumentError, "unknown period #{period.inspect}"
      end
    end

    def self.of_season(season)
      return FirstDiscovery.none unless season

      FirstDiscovery.where(card_season_id: Catalog::CardSeason.where(season_id: season.id).select(:id))
    end

    private_class_method :of_period, :of_season
  end
end

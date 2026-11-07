module Game
  module FortuneStanding
    PERIODS = %i[week all_time].freeze

    Standing = Data.define(:period, :index, :z_score, :rank, :ranked_count, :privileged, :packs, :cards, :actual_points, :expected_points,
      :variance) do
      include LuckShare

      def label = FortuneIndex.label(index)
      def packs_opened = packs.values.sum
      def opened? = packs_opened.positive?
    end

    SQL = <<~SQL.squish.freeze
      WITH ranked AS (
        SELECT player_id, week_start, z_score FROM game_fortunes
        WHERE player_id IN (SELECT id FROM accounts_players WHERE banned_at IS NULL AND deleted_at IS NULL)
          AND (week_start IS NOT DISTINCT FROM :period_week OR week_start = :week)
      ),
      mine AS (SELECT * FROM game_fortunes WHERE player_id = :player_id AND week_start IS NOT DISTINCT FROM :period_week),
      mine_this_week AS (SELECT z_score FROM ranked WHERE player_id = :player_id AND week_start = :week)
      SELECT mine.*,
        1 + (SELECT COUNT(*) FROM ranked WHERE ranked.week_start IS NOT DISTINCT FROM :period_week
          AND (ranked.z_score > mine.z_score OR (ranked.z_score = mine.z_score AND ranked.player_id < mine.player_id))) AS rank,
        (SELECT COUNT(*) FROM ranked WHERE ranked.week_start IS NOT DISTINCT FROM :period_week) AS ranked_count,
        COALESCE((SELECT COUNT(*) FROM ranked, mine_this_week WHERE ranked.week_start = :week
          AND (ranked.z_score > mine_this_week.z_score OR (ranked.z_score = mine_this_week.z_score AND ranked.player_id < :player_id)))
          < ((SELECT COUNT(*) FROM ranked WHERE ranked.week_start = :week) + :per - 1) / :per
          AND EXISTS (SELECT 1 FROM mine_this_week), FALSE) AS privileged
      FROM mine
    SQL

    def self.call(player, period:, now: Time.current)
      raise ArgumentError, "unknown period #{period.inspect}" unless PERIODS.include?(period)
      return empty(period) if player.nil?

      week = WeeklyGoal.week_start(now)
      fortune = Fortune.find_by_sql([ SQL, { player_id: player.id, week:, period_week: (week if period == :week),
        per: FortuneIndex::PRIVILEGED_PER } ]).first
      fortune ? standing(period, fortune) : empty(period)
    end

    def self.standing(period, fortune)
      Standing.new(period:, index: FortuneIndex.of(fortune.z_score), z_score: fortune.z_score, rank: fortune.rank,
        ranked_count: fortune.ranked_count, privileged: fortune.privileged, packs: fortune.packs_by_kind,
        cards: fortune.cards_by_tier, actual_points: fortune.actual_points, expected_points: fortune.expected_points,
        variance: fortune.variance)
    end

    def self.empty(period)
      Standing.new(period:, index: 0, z_score: 0.0, rank: nil, ranked_count: 0, privileged: false,
        packs: Fortune::PACK_COLUMNS.transform_values { 0 }, cards: Fortune::CARD_COLUMNS.transform_values { 0 },
        actual_points: 0, expected_points: 0.0, variance: 0.0)
    end

    private_class_method :standing, :empty
  end
end

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

    def self.call(player, period:, now: Time.current)
      raise ArgumentError, "unknown period #{period.inspect}" unless PERIODS.include?(period)
      return empty(period) if player.nil?

      fortune = Fortune.of_period(period, now).find_by(player_id: player.id)
      fortune ? standing(period, fortune, player, now) : empty(period)
    end

    def self.standing(period, fortune, player, now)
      board = Fortune.of_period(period, now).listed
      listed = board.exists?(player_id: player.id)
      Standing.new(period:, index: FortuneIndex.of(fortune.z_score), z_score: fortune.z_score, rank: (board.ahead_of(fortune).count + 1 if listed),
        ranked_count: listed ? board.count : 0, privileged: Privileged.call(player, now:), packs: fortune.packs_by_kind,
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

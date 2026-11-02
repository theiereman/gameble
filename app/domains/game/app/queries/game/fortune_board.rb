module Game
  module FortuneBoard
    SHOWN = 50

    Row = Data.define(:rank, :player, :index, :privileged) do
      def label = FortuneIndex.label(index)
    end

    Board = Data.define(:period, :rows, :ranked_count, :active_count, :privileged_count, :own)

    def self.call(viewer, period:, now: Time.current, shown: SHOWN)
      raise ArgumentError, "unknown period #{period.inspect}" unless FortuneStanding::PERIODS.include?(period)

      ranked = Fortune.of_period(period, now).ranked
      privileged = Privileged.ids(now:)
      top = ranked.limit(shown).to_a
      players = Accounts::Player.where(id: top.map(&:player_id)).index_by(&:id)
      rows = top.each_with_index.map do |fortune, offset|
        Row.new(rank: offset + 1, player: players.fetch(fortune.player_id), index: FortuneIndex.of(fortune.z_score),
          privileged: privileged.include?(fortune.player_id))
      end
      Board.new(period:, rows:, ranked_count: ranked.count, active_count: Fortune.week_of(now).ranked.count, privileged_count: privileged.size,
        own: own_row(viewer, rows, ranked, privileged, now, period))
    end

    def self.own_row(viewer, rows, ranked, privileged, now, period)
      return nil if viewer.nil? || rows.any? { |row| row.player == viewer }

      fortune = Fortune.of_period(period, now).find_by(player_id: viewer.id)
      return nil if fortune.nil?

      Row.new(rank: ranked.ahead_of(fortune).count + 1, player: viewer, index: FortuneIndex.of(fortune.z_score),
        privileged: privileged.include?(viewer.id))
    end

    private_class_method :own_row
  end
end

module Game
  module FortuneBoard
    PAGE_SIZE = 24

    SORTS = %i[luck capsules].freeze

    Row = Data.define(:rank, :ranked_count, :player, :shown, :index, :privileged, :packs_opened, :rarities) do
      include LuckShare

      def label = FortuneIndex.label(index)
    end

    Summary = Data.define(:period, :ranked_count, :active_count, :privileged_count, :packs_opened)

    PACKS = "game_fortunes.regular_packs + game_fortunes.bonus_packs + game_fortunes.reward_packs".freeze

    def self.ranked(period, now: Time.current, sort: :luck)
      raise ArgumentError, "unknown period #{period.inspect}" unless FortuneStanding::PERIODS.include?(period)

      numbered = Fortune.of_period(period, now).ranked
        .select("game_fortunes.*", Arel.sql("ROW_NUMBER() OVER (ORDER BY z_score DESC, player_id ASC) AS luck_rank"))
      board = Fortune.from(numbered, :game_fortunes)
      sort == :capsules ? board.order(Arel.sql("#{PACKS} DESC"), :luck_rank) : board.order(:luck_rank)
    end

    def self.rows(fortunes, ranked_count:, viewer: nil, now: Time.current, with_rarities: true)
      ids = fortunes.map(&:player_id)
      players = Accounts::Player.where(id: ids).index_by(&:id)
      privileged = Privileged.ids(now:)
      rarities = with_rarities ? HeldGames.by_rarity_among(ids) : {}
      friends = viewer ? Friendship.other_ids(viewer.id).to_set : Set.new
      fortunes.map do |fortune|
        player = players.fetch(fortune.player_id)
        Row.new(rank: fortune.luck_rank, ranked_count:, player:, shown: Visibility.visible?(viewer, player, friends:), index: FortuneIndex.of(fortune.z_score),
          privileged: privileged.include?(fortune.player_id), packs_opened: fortune.packs_by_kind.values.sum,
          rarities: rarities[fortune.player_id])
      end
    end

    def self.summary(period, now: Time.current)
      ranked = Fortune.of_period(period, now).ranked
      active = Fortune.week_of(now).ranked.count
      Summary.new(period:, ranked_count: ranked.count, active_count: active,
        privileged_count: FortuneIndex.privileged_count(active), packs_opened: ranked.sum(Arel.sql(PACKS)))
    end
  end
end

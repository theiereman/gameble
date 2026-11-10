module Game
  module CardBackShelf
    SET_GROUPS = %i[theme hall_of_fame].freeze
    GROUPS = [ :base, :achievement, *SET_GROUPS ].freeze

    Row = Data.define(:back, :state, :season, :seasons, :unlocked_at, :tier, :progress, :group) do
      def key = back.key
      def asset = back.asset
      def unlock = back.unlock
      def active? = state == :active
      def locked? = state == :locked
      def choosable_season? = seasons.size > 1
    end

    def self.call(player)
      active, active_season = CardBacks.active_with_season(player)
      unlocks = CardBackUnlock.where(player_id: player.id).pluck(:back, :unlocked_at).to_h
      earned = EarnedSetBacks.rows(player)
      seasons = CardBackSeasons.of(earned)
      tiers = latest_tiers(earned)
      states = CardBacks::CATALOGUE.to_h { [ it.key, state(it, active:, unlocked: unlocks) ] }
      progress = SetBackProgress.call(player, states.select { |_, state| state == :locked }.keys)

      CardBacks::CATALOGUE.map do |back|
        state = states.fetch(back.key)
        Row.new(back:, state:, season: (active_season if state == :active), seasons: seasons.fetch(back.key, []),
          unlocked_at: unlocks[back.key], tier: tiers[back.key], progress: progress[back.key], group: group(back))
      end
    end

    def self.state(back, active:, unlocked:)
      if back.key == active then :active
      elsif CardBacks.held_by_everyone?(back) || unlocked.key?(back.key) then :unlocked
      else :locked
      end
    end

    def self.group(back)
      case back.unlock.kind
      when :always then :base
      when :set_tier then back.unlock.target.first.to_sym
      else back.unlock.kind
      end
    end

    def self.latest_tiers(earned)
      earned.group_by { |kind, key, _, _| CardBacks.set_key(kind, key) }.transform_values do |rows|
        rows.max_by { |_, _, number, tier| [ number, Catalog::SetTier::TIERS.index(tier) || -1 ] }.last
      end
    end

    private_class_method :state, :group, :latest_tiers
  end
end

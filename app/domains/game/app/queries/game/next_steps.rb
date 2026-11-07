module Game
  module NextSteps
    ClosestSet = Data.define(:set, :standing)
    Steps = Data.define(:closest_set, :friend, :rewards)

    def self.call(player, season:)
      Steps.new(
        closest_set: closest_set(player, season),
        friend: TradeSuggestions.call(player).suggestions.first&.player,
        rewards: UnclaimedAchievements.count(player)
      )
    end

    def self.closest_set(player, season)
      ranked = SetBoard.call(player, season:).in_progress.each_with_index
        .select { |standing, _index| standing.missing }
        .sort_by { |standing, index| [ standing.missing, index ] }
        .map(&:first)
      sets = Catalog::SetsById.call(ranked.map(&:set_id))
      standing = ranked.find { sets.key?(it.set_id) }
      ClosestSet.new(set: sets[standing.set_id], standing:) if standing
    end

    private_class_method :closest_set
  end
end

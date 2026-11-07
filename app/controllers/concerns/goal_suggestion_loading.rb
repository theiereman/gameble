module GoalSuggestionLoading
  extend ActiveSupport::Concern
  include SetBoardLoading

  Suggestion = Data.define(:set, :standing)

  SUGGESTIONS = 3

  private
    def goal_suggestions(owner, season:)
      closest = Game::SetsInProgress.call(owner, season:).values.select { it.started? && !it.complete? }
        .min_by(SUGGESTIONS) { completion_order(it) }
      sets = Catalog::SetsById.call(closest.map(&:set_id))
      closest.filter_map { |standing| Suggestion.new(set: sets[standing.set_id], standing:) if sets.key?(standing.set_id) }
    end
end

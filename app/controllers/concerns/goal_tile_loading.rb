module GoalTileLoading
  extend ActiveSupport::Concern
  include SetBoardLoading

  GoalTile = Data.define(:need, :missing_cards, :more_missing)
  Suggestion = Data.define(:set, :standing)

  MISSING_SHOWN = 5
  SUGGESTIONS = 3

  private
    def goal_tiles(needs)
      editions = Catalog::LatestPublishedCardSeasons.call(needs.flat_map(&:missing_card_ids))
      missing = needs.map { |need| need.missing_card_ids.select { editions.key?(it) } }
      views = Catalog::CardViews.call(missing.flat_map { it.first(MISSING_SHOWN) }.map { editions.fetch(it) }, locale: I18n.locale)
      needs.zip(missing).map do |need, card_ids|
        shown = card_ids.first(MISSING_SHOWN).filter_map { views[editions.fetch(it)] }
        GoalTile.new(need:, missing_cards: shown, more_missing: need.missing_card_ids.size - shown.size)
      end
    end

    def goal_suggestions(owner, season:)
      closest = Game::SetsInProgress.call(owner, season:).values.select { it.started? && !it.complete? }
        .min_by(SUGGESTIONS) { completion_order(it) }
      sets = Catalog::SetsById.call(closest.map(&:set_id))
      closest.filter_map { |standing| Suggestion.new(set: sets[standing.set_id], standing:) if sets.key?(standing.set_id) }
    end
end

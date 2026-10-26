module SetBoardLoading
  extend ActiveSupport::Concern

  SetRow = Data.define(:set, :standing)
  SetTile = Data.define(:set, :standing, :showcase, :closest)

  NO_SHOWCASE = Game::SetShowcases::Showcase.new(slots: [], others: 0, last_gained: nil)

  private
    def load_set_search(season, owner:)
      @query = SetSearch.clean(params[:q].is_a?(String) ? params[:q] : "")
      search = SetSearch.call(season:, query: @query, locale: I18n.locale)
      standings = search.sets.empty? ? {} : Game::SetsInProgress.call(owner, season:)
      @results = search_rows(search.sets, standings)
      @results_count = search.count
    end

    def load_set_tiles(season, owner:)
      in_progress = Game::SetBoard.call(owner, season:).in_progress
      @tiles = set_tiles(set_rows(in_progress, Catalog::SetsById.call(in_progress.map(&:set_id))), owner:, season:)
    end

    def set_rows(standings, sets)
      standings.filter_map { |standing| SetRow.new(set: sets[standing.set_id], standing:) if sets.key?(standing.set_id) }
    end

    def set_tiles(rows, owner:, season:)
      showcases = Game::SetShowcases.call(owner, set_ids: rows.map { it.set.id }, season:, locale: I18n.locale)
      closest = closest_to_next_tier(rows)
      rows.map do |row|
        SetTile.new(set: row.set, standing: row.standing, showcase: showcases.fetch(row.set.id, NO_SHOWCASE), closest: row.equal?(closest))
      end
    end

    def closest_to_next_tier(rows)
      rows.each_with_index.select { |row, _index| row.standing.missing }.min_by { |row, index| [ row.standing.missing, index ] }&.first
    end

    def search_rows(found, standings)
      unstarted = Catalog::SetFigures.call(found.map(&:id).reject { standings.key?(it) })
      found.filter_map do |set|
        standing = standings[set.id] || unstarted[set.id]&.then { Game::SetStanding.unstarted(set_id: set.id, total: it.total, tiers: it.tiers) }
        SetRow.new(set:, standing:) if standing
      end
    end
end

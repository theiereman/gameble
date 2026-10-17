module SetBoardLoading
  extend ActiveSupport::Concern

  SetRow = Data.define(:set, :standing)

  private
    def load_set_board(season, owner:)
      @query = SetSearch.clean(params[:q].is_a?(String) ? params[:q] : "")
      board = Game::SetBoard.call(owner, season:)
      search = SetSearch.call(season:, query: @query, locale: I18n.locale)
      shown = board.in_progress + board.discover
      sets = Catalog::SetsById.call(shown.map(&:set_id))
      @in_progress = set_rows(board.in_progress, sets)
      @discover = set_rows(board.discover, sets)
      @results = search_rows(search.sets, board.standings)
      @results_count = search.count
    end

    def set_rows(standings, sets)
      standings.filter_map { |standing| SetRow.new(set: sets[standing.set_id], standing:) if sets.key?(standing.set_id) }
    end

    def search_rows(found, standings)
      unstarted = Catalog::SetFigures.call(found.map(&:id).reject { standings.key?(it) })
      found.filter_map do |set|
        standing = standings[set.id] || unstarted[set.id]&.then { Game::SetStanding.unstarted(set_id: set.id, total: it.total, tiers: it.tiers) }
        SetRow.new(set:, standing:) if standing
      end
    end
end

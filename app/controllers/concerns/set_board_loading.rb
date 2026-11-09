module SetBoardLoading
  extend ActiveSupport::Concern

  SetRow = Data.define(:set, :standing)
  SetTile = Data.define(:set, :standing, :showcase, :closest) do
    def own? = false
  end
  OwnSetTile = Data.define(:own_set, :showcase) do
    def own? = true

    def closest = false

    def standing = own_set.to_set_standing
  end

  PREVIEW_TILES = 6
  BROWSER_PAGE_SIZE = 24

  NO_SHOWCASE = Game::SetShowcases::Showcase.new(slots: [], others: 0, last_gained: nil)

  private
    def browsable_own_sets(owner)
      Game::CustomSetStandings.call(owner).select { it.custom? || it.ever_synced? }
    end

    def own_set_tiles(own_sets, owner:, season:)
      showcases = Game::SetShowcases.custom_sets(owner, tokens: own_sets.map(&:token), season:, locale: I18n.locale)
      own_sets.map { OwnSetTile.new(own_set: it, showcase: showcases.fetch(it.token, NO_SHOWCASE)) }
    end

    def load_in_progress_preview(season, owner:, goals:)
      board = Game::SetBoard.call(owner, season:)
      sets = Catalog::SetsById.call(board.in_progress.map(&:set_id))
      rows = set_rows(board.in_progress, sets).reject { aimed_at?(it.set, goals) }.sort_by { closest_order(it.standing) }
      @in_progress_tiles = set_tiles(rows.first(PREVIEW_TILES), owner:, season:)
      @more_in_progress = rows.size > PREVIEW_TILES
    end

    def load_set_browser(season, owner:, goals:, page:)
      named = browsable_own_sets(owner).index_with { helpers.custom_set_display_name(it) }
      @browser = SetBrowser.new(season:, player: owner, own_sets: named, goals:, filters: params)
      @browser_pagy, shown = pagy(:offset, @browser.entries, limit: BROWSER_PAGE_SIZE, page:)
      @browser_tiles = browser_tiles(shown, owner:, season:)
    end

    def browser_tiles(entries, owner:, season:)
      own, game = entries.partition(&:own?)
      tiles = set_tiles(game, owner:, season:, closest: nil).index_by(&:set)
        .merge(own_set_tiles(own.map(&:own_set), owner:, season:).index_by(&:own_set))
      entries.map { tiles.fetch(it.own_set || it.set) }
    end

    def closest_order(standing)
      [ standing.missing || 0, *completion_order(standing) ]
    end

    def completion_order(standing)
      [ standing.total - standing.held, -standing.share, standing.set_id ]
    end

    def aimed_at?(set, goals)
      goals.any? { it.aims_at?(kind: set.kind, key: set.key) }
    end

    def set_rows(standings, sets)
      standings.filter_map { |standing| SetRow.new(set: sets[standing.set_id], standing:) if sets.key?(standing.set_id) }
    end

    def set_tiles(rows, owner:, season:, closest: closest_to_next_tier(rows))
      showcases = Game::SetShowcases.call(owner, set_ids: rows.map { it.set.id }, season:, locale: I18n.locale)
      rows.map do |row|
        SetTile.new(set: row.set, standing: row.standing, showcase: showcases.fetch(row.set.id, NO_SHOWCASE), closest: row.equal?(closest))
      end
    end

    def closest_to_next_tier(rows)
      rows.each_with_index.select { |row, _index| row.standing.missing }.min_by { |row, index| [ row.standing.missing, index ] }&.first
    end
end

module SetBoardLoading
  extend ActiveSupport::Concern

  SetRow = Data.define(:set, :standing)
  SetTile = Data.define(:set, :standing, :showcase, :closest)
  TilePage = Data.define(:tiles, :next_offset)

  TILES_PER_PAGE = 6
  BOARD_SECTIONS = %w[in_progress completed].freeze

  NO_SHOWCASE = Game::SetShowcases::Showcase.new(slots: [], others: 0, last_gained: nil)

  private
    def tile_offset
      params[:offset].to_s.match?(/\A\d{1,5}\z/) ? params[:offset].to_i : 0
    end

    def load_set_search(season, owner:, offset: 0)
      @query = SetSearch.clean(params[:q].is_a?(String) ? params[:q] : "")
      search = SetSearch.call(season:, query: @query, locale: I18n.locale)
      shown = search.sets.drop(offset).first(TILES_PER_PAGE)
      standings = shown.empty? ? {} : Game::SetsInProgress.call(owner, season:)
      tiles = set_tiles(search_rows(shown, standings), owner:, season:, closest: nil)
      @results = TilePage.new(tiles:, next_offset: next_offset(offset, search.sets.size))
      @results_count = search.count
    end

    def load_set_tiles(season, owner:, section: nil, offset: 0)
      board = Game::SetBoard.call(owner, season:)
      sets = Catalog::SetsById.call((board.in_progress + board.complete).map(&:set_id))
      in_progress = set_rows(board.in_progress, sets)
      lists = { "in_progress" => in_progress, "completed" => set_rows(board.complete, sets) }
      shown = section ? [ section ] : BOARD_SECTIONS
      start = section ? offset : 0
      windows = shown.to_h { [ it, lists.fetch(it).drop(start).first(TILES_PER_PAGE) ] }
      tiles = set_tiles(windows.values.flatten(1), owner:, season:, closest: closest_to_next_tier(in_progress))
      pages = windows.to_h do |name, rows|
        [ name, TilePage.new(tiles: tiles.shift(rows.size), next_offset: next_offset(start, lists.fetch(name).size)) ]
      end
      @in_progress_page = pages["in_progress"]
      @completed_page = pages["completed"]
    end

    def next_offset(start, total)
      start + TILES_PER_PAGE if start + TILES_PER_PAGE < total
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

    def search_rows(found, standings)
      unstarted = Catalog::SetFigures.call(found.map(&:id).reject { standings.key?(it) })
      found.filter_map do |set|
        standing = standings[set.id] || unstarted[set.id]&.then { Game::SetStanding.unstarted(set_id: set.id, total: it.total, tiers: it.tiers) }
        SetRow.new(set:, standing:) if standing
      end
    end
end

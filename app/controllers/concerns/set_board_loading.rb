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
  TilePage = Data.define(:tiles, :next_offset)

  TILES_PER_PAGE = 6
  COMPLETED = "completed".freeze
  BOARD_SECTIONS = [ *Catalog::SetKind::ALL, COMPLETED ].freeze

  NO_SHOWCASE = Game::SetShowcases::Showcase.new(slots: [], others: 0, last_gained: nil)

  private
    def tile_offset
      params[:offset].to_s.match?(/\A\d{1,5}\z/) ? params[:offset].to_i : 0
    end

    def load_set_search(season, owner:, own_sets: [], offset: 0)
      @query = SetSearch.clean(params[:q].is_a?(String) ? params[:q] : "")
      named = own_sets.index_with { helpers.custom_set_display_name(it) }
      search = SetSearch.call(season:, query: @query, locale: I18n.locale, own_sets: named)
      shown = search.sets.drop(offset).first(TILES_PER_PAGE)
      @results = TilePage.new(tiles: search_tiles(shown, owner:, season:), next_offset: next_offset(offset, search.sets.size))
      @results_count = search.count
    end

    def own_set_tiles(own_sets, owner:, season:)
      showcases = Game::SetShowcases.custom_sets(owner, tokens: own_sets.map(&:token), season:, locale: I18n.locale)
      own_sets.map { OwnSetTile.new(own_set: it, showcase: showcases.fetch(it.token, NO_SHOWCASE)) }
    end

    def load_set_tiles(season, owner:, section: nil, offset: 0, goals: [])
      board = Game::SetBoard.call(owner, season:)
      sets = Catalog::SetsById.call((board.in_progress + board.complete).map(&:set_id))
      groups = kind_groups(set_rows(board.in_progress, sets).reject { aimed_at?(it.set, goals) })
      lists = groups.merge(COMPLETED => set_rows(board.complete, sets))
      shown = section ? [ section ] : lists.keys
      start = section ? offset : 0
      windows = shown.to_h { [ it, lists.fetch(it, []).drop(start).first(TILES_PER_PAGE) ] }
      tiles = set_tiles(windows.values.flatten(1), owner:, season:, closest: closest_to_next_tier(groups.values.flatten(1)))
      pages = windows.to_h do |name, rows|
        [ name, TilePage.new(tiles: tiles.shift(rows.size), next_offset: next_offset(start, lists.fetch(name, []).size)) ]
      end
      @completed_page = pages.delete(COMPLETED)
      @group_pages = pages
    end

    def kind_groups(rows)
      Catalog::SetKind::ALL.to_h { |kind| [ kind, rows.select { it.set.kind == kind }.sort_by { completion_order(it.standing) } ] }
        .reject { |_kind, group| group.empty? }
    end

    def completion_order(standing)
      [ standing.total - standing.held, -standing.share, standing.set_id ]
    end

    def aimed_at?(set, goals)
      goals.any? { it.aims_at?(kind: set.kind, key: set.key) }
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

    def search_tiles(shown, owner:, season:)
      own_sets, game_sets = shown.partition { it.is_a?(Game::CustomSetStandings::Standing) }
      standings = game_sets.empty? ? {} : Game::SetsInProgress.call(owner, season:)
      tiles = set_tiles(search_rows(game_sets, standings), owner:, season:, closest: nil).index_by(&:set)
        .merge(own_set_tiles(own_sets, owner:, season:).index_by(&:own_set))
      shown.filter_map { tiles[it] }
    end

    def search_rows(found, standings)
      unstarted = Catalog::SetFigures.call(found.map(&:id).reject { standings.key?(it) })
      found.filter_map do |set|
        standing = standings[set.id] || unstarted[set.id]&.then { Game::SetStanding.unstarted(set_id: set.id, total: it.total, tiers: it.tiers) }
        SetRow.new(set:, standing:) if standing
      end
    end
end

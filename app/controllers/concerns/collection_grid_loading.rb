# The collection's grid as its parameters ask for it: one tile per game, of
# the whole season and of every game the viewer holds in any edition
# (Game::CollectionTiles), for a controller that shows it (LibraryController) or walks it from a
# card's detail (CardsController, from the `grid` parameter the grid's
# links carry): one source for its filters and its order, so the detail
# walks the cards the grid showed, in the same order.
#
# The parameters, read from `source` (the request's parameters, or the
# detail's `grid`), anything unknown ignored: the filters, each a list,
# `state[]` (owned, all, missing, new, duplicates; none asked is every
# slot, Game::CollectionStates::DEFAULT), `rarity[]`,
# `sets[]` ("kind:key"), `genre[]`; `q`, the text
# searched; `seen`, on the detail's `grid` only, the watermark the grid was
# shown against (ISO 8601), so the new cards it showed stay new while the
# detail walks them, though showing them moved the player's watermark. A
# visitor owns nothing: the states are a player's, ignored for a visitor.
module CollectionGridLoading
  extend ActiveSupport::Concern

  # The grid's slots per page.
  GRID_SIZE = 60
  # The watermark of a player who has seen no card yet: before any gain.
  NOTHING_SEEN = Time.utc(1970)
  # The filters' list parameters, as the grid's links carry them.
  LIST_FILTERS = %i[state rarity sets genre].freeze
  # No list of the library goes this far; a larger page would overflow the OFFSET.
  MAX_PAGE = 100_000

  private
    # The Catalog::CollectionGrid of the viewer's tiles over `season`,
    # filtered as `source` asks.
    def collection_grid(season, source)
      Catalog::CollectionGrid.call(season:, cards: Game::CollectionTiles.call(grid_owner, season), genres: grid_list(source, :genre), rarities: grid_list(source, :rarity),
        sets: grid_list(source, :sets), query: grid_query(source), locale: I18n.locale)
    end

    # The grid's card-seasons narrowed to `states`, newest gained first, new
    # judged against `seen_up_to` when given.
    def grid_cards(grid, states, seen_up_to: nil)
      Game::CollectionStates.call(grid_owner, grid.card_seasons, states:, newest_first: true, seen_up_to:)
    end

    # The watermark the grid `source` names was shown against; nil when it
    # names none or not a time (the player's current watermark then).
    def grid_seen(source)
      value = source[:seen]
      Time.iso8601(value) if value.is_a?(String)
    rescue ArgumentError
      nil
    end

    # Whose holdings the grid shows: the viewer's, unless a controller names
    # another player's.
    def grid_owner
      current_player
    end

    # Whether the grid is another player's: the viewer's watermark is not
    # theirs, so it knows no new state and carries the owner's token.
    def grid_another?
      false
    end

    # The states `source` asks for, in Game::CollectionStates order; none
    # for a grid without an owner, and never new on another player's.
    def grid_states_asked(source)
      return [] if grid_owner.nil?

      states = Game::CollectionStates.sanitize(grid_list(source, :state))
      grid_another? ? states - [ "new" ] : states
    end

    # The text searched, stripped and cut to Catalog::CollectionGrid::MAX_QUERY.
    def grid_query(source)
      source[:q].to_s.strip.first(Catalog::CollectionGrid::MAX_QUERY)
    end

    # The strings of a list parameter of `source`, [] for anything else.
    def grid_list(source, key)
      Array.wrap(source[key]).grep(String)
    end

    # The grid's filters and search as a card's detail carries them, so it
    # walks the grid shown and leads back to it: the lists asked, the text
    # searched (always, even blank: the context is never empty), and the
    # watermark `seen` it was shown against, when given. A visitor's names
    # no state.
    def grid_context(source, seen: nil)
      lists = grid_list_filters.to_h { [ it, grid_list(source, it) ] }
      lists[:state] -= [ "new" ] if grid_another? && lists.key?(:state)
      context = { **lists.compact_blank, q: grid_query(source) }
      context[:brother] = grid_owner.token if grid_another?
      context.merge!(seen: seen.utc.iso8601(6)) if seen
      context
    end

    # The list filters the grid reads: an ownerless grid's, all but the states.
    def grid_list_filters
      grid_owner ? LIST_FILTERS : LIST_FILTERS - %i[state]
    end

    # @grid_pagy and @slots: [ [ Catalog::CardView, Game::HeldGames::Edition | nil ], … ]
    # in grid order, nil for a game the grid's owner does not hold; @grid_context,
    # the filters and search each slot's link carries, so the card's
    # detail walks this grid (CollectionGridLoading#grid_context), with the
    # player's watermark when the grid shows new cards by filter: showing
    # them moves it (collection_seen_controller.ts), and the detail judges
    # new against the one this grid was shown against. The
    # filters on: @query, @states (those asked, else every slot) and
    # @states_asked. @seen_up_to: the latest gain among the new cards
    # shown, nil when none is.
    def load_grid(grid)
      @query = grid_query(params)
      asked = grid_states_asked(params)
      @states_asked = asked.any?
      @states = @states_asked ? asked : [ Game::CollectionStates::DEFAULT ]
      @grid_context = grid_context(params, seen: (shown_watermark if @states.include?("new")))
      @grid_pagy, page = pagy(:offset, grid_cards(grid, @states), limit: GRID_SIZE, page: page_param, querify: pages_query)
      tiles = page.pluck(:id, :card_id)
      views = Catalog::CardViews.call(tiles.map(&:first), locale: I18n.locale)
      held = Game::HeldGames.editions(grid_owner, card_ids: tiles.map(&:last), season: @season)
      @slots = tiles.filter_map { |id, card_id| [ views[id], held[card_id] ] if views.key?(id) }
      @seen_up_to = held.values.select(&:new).map(&:gained_at).max unless grid_another?
    end

    # An ownerless grid's pages name no state: it ignores it.
    def pages_query
      ->(query) { query.delete("state") } if grid_owner.nil?
    end

    def load_set_filter(grid)
      @set_kinds = Catalog::SetKind::ALL & Catalog::SeasonSets.kinds(season: @season)
      return if @set_kinds.empty?

      @set_kind = @set_kinds.include?(params[:set_kind]) ? params[:set_kind] : @set_kinds.first
      @set_query = SetSearch.clean(params[:set_q].is_a?(String) ? params[:set_q] : "")
      found = SetSearch.in_kind(season: @season, kind: @set_kind, query: @set_query, locale: I18n.locale,
        except: grid.chosen_sets.map { [ it.kind, it.key ] })
      @set_options = grid.chosen_sets + found.sets
      @set_found = found.count
    end

    # The watermark this grid judges new cards against; for a player who
    # has seen none yet, a time before any gain, so every gain stays new.
    def shown_watermark
      Game::CollectionWatermark.call(current_player) || NOTHING_SEEN
    end

    # The grid owner's games held per best rarity (@games_by_rarity), the games held
    # (@unique) out of the season's cards (@season_cards), and the copies
    # held per rarity tier (@tier_counts), every edition counted.
    def load_summary
      @games_by_rarity = Game::HeldGames.by_rarity(grid_owner)
      @unique = @games_by_rarity.values.sum
      @season_cards = Catalog::CardCount.call(@season)
      @tier_counts = Game::TierCounts.call(grid_owner)
    end

    # The page asked for: a number from 1 to MAX_PAGE, 1 for anything that
    # is not one.
    def page_param
      params[:page].to_s.to_i.clamp(1, MAX_PAGE)
    end
end

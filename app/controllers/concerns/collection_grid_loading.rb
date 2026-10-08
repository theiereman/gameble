# The collection's grid as its parameters ask for it, for a controller
# that shows it (LibraryController) or walks it from a card's detail
# (CardsController, from the `grid` parameter the grid's links carry): one
# source for its scope, its filters and its order, so the detail walks the
# cards the grid showed, in the same order.
#
# The parameters, read from `source` (the request's parameters, or the
# detail's `grid`), anything unknown ignored: the filters, each a list,
# `state[]` (owned, all, missing, new, duplicates; none asked is owned, or
# every slot for a viewer who owns no card of the season yet), `rarity[]`,
# `sets[]` ("kind:key", whole season only), `genre[]`; `q`, the text
# searched; `seen`, on the detail's `grid` only, the watermark the grid was
# shown against (ISO 8601), so the new cards it showed stay new while the
# detail walks them, though showing them moved the player's watermark.
module CollectionGridLoading
  extend ActiveSupport::Concern

  # The grid's slots per page.
  GRID_SIZE = 60
  # The watermark of a player who has seen no card yet: before any gain.
  NOTHING_SEEN = Time.utc(1970)
  # The filters' list parameters, as the grid's links carry them.
  LIST_FILTERS = %i[state rarity sets genre].freeze

  private
    # The Catalog::CollectionGrid of `season`, or of its set `kind` and
    # `key` when given, filtered as `source` asks; nil for a set the season
    # does not hold.
    def collection_grid(season, source, kind: nil, key: nil)
      Catalog::CollectionGrid.call(season:, kind:, key:, genres: grid_list(source, :genre), rarities: grid_list(source, :rarity),
        sets: grid_list(source, :sets), query: grid_query(source), locale: I18n.locale)
    end

    # The grid's card-seasons in its order, narrowed to `states`, new judged
    # against `seen_up_to` when given: the whole season newest gained first,
    # a set in its slot order.
    def grid_cards(grid, states, seen_up_to: nil)
      Game::CollectionStates.call(current_player, grid.card_seasons, states:, newest_first: grid.set.nil?, seen_up_to:)
    end

    # The watermark the grid `source` names was shown against; nil when it
    # names none or not a time (the player's current watermark then).
    def grid_seen(source)
      value = source[:seen]
      Time.iso8601(value) if value.is_a?(String)
    rescue ArgumentError
      nil
    end

    # The states `source` asks for, in Game::CollectionStates order.
    def grid_states_asked(source)
      Game::CollectionStates.sanitize(grid_list(source, :state))
    end

    # The state shown when none is asked: the owned cards, or every slot
    # when the viewer owns none of the season's `unique` cards yet.
    def grid_default_state(unique)
      unique.positive? ? "owned" : "all"
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
    # searched (always, even blank: the context is never empty), the set's
    # kind and key on a set's grid, and the watermark `seen` it was shown
    # against, when given.
    def grid_context(source, set, seen: nil)
      lists = LIST_FILTERS.to_h { [ it, grid_list(source, it) ] }.compact_blank
      context = { **lists, q: grid_query(source) }
      context.merge!(kind: set.kind, key: set.key) if set
      context.merge!(seen: seen.utc.iso8601(6)) if seen
      context
    end
end

module CollectionGridLoading
  extend ActiveSupport::Concern

  include GoalMarksLoading

  GRID_SIZE = 60
  NOTHING_SEEN = Time.utc(1970)
  LIST_FILTERS = %i[state rarity sets genre goals].freeze
  # A larger page number would overflow Postgres' OFFSET.
  MAX_PAGE = 100_000

  private
    def collection_grid(season, source)
      Catalog::CollectionGrid.call(season:, cards: Game::CollectionTiles.call(grid_owner, season), genres: grid_list(source, :genre), rarities: grid_list(source, :rarity),
        sets: grid_list(source, :sets), query: grid_query(source), locale: I18n.locale, card_ids: grid_goal_card_ids(source))
    end

    def grid_goals
      grid_another? || grid_owner.nil? ? GoalMarks::NONE : goal_marks
    end

    def grid_goals_chosen(source)
      grid_goals.chosen(grid_list(source, :goals))
    end

    def grid_goal_card_ids(source)
      chosen = grid_goals_chosen(source)
      grid_goals.card_ids_of(chosen) if chosen.any?
    end

    def grid_cards(grid, states, seen_up_to: nil, price: Game::Market::CollectionPrices::NONE)
      cards = Game::CollectionStates.call(grid_owner, grid.card_seasons, states:, newest_first: true, seen_up_to:)
      Game::Market::CollectionPrices.apply(cards, price, owner: grid_owner)
    end

    def market_state
      @market_state ||= Game::Market::MarketState.call
    end

    def grid_price(source)
      Game::Market::CollectionPrices.choice(sort: source[:sort], minimum: source[:min_price], maximum: source[:max_price], state: market_state)
    end

    def grid_seen(source)
      value = source[:seen]
      Time.iso8601(value) if value.is_a?(String)
    rescue ArgumentError
      nil
    end

    def grid_owner
      current_player
    end

    def grid_another?
      false
    end

    def grid_states_asked(source)
      return [] if grid_owner.nil?

      states = Game::CollectionStates.sanitize(grid_list(source, :state))
      grid_another? ? states - [ "new" ] : states
    end

    def grid_query(source)
      source[:q].to_s.strip.first(Catalog::CollectionGrid::MAX_QUERY)
    end

    def grid_list(source, key)
      Array.wrap(source[key]).grep(String)
    end

    def grid_context(source, seen: nil, price: grid_price(source))
      lists = grid_list_filters.to_h { [ it, grid_list(source, it) ] }
      lists[:state] -= [ "new" ] if grid_another? && lists.key?(:state)
      context = { **lists.compact_blank, q: grid_query(source), **price.params }
      context[:brother] = grid_owner.token if grid_another?
      context.merge!(seen: seen.utc.iso8601(6)) if seen
      context
    end

    def grid_list_filters
      filters = grid_owner ? LIST_FILTERS : LIST_FILTERS - %i[state]
      grid_goals.any? ? filters : filters - %i[goals]
    end

    def load_grid(grid)
      @query = grid_query(params)
      asked = grid_states_asked(params)
      @states_asked = asked.any?
      @states = @states_asked ? asked : [ Game::CollectionStates::DEFAULT ]
      @grid_goals = grid_goals
      @goals_chosen = grid_goals_chosen(params)
      @grid_price = grid_price(params)
      @price_offered = market_state.first_opened?
      @grid_context = grid_context(params, seen: (shown_watermark if @states.include?("new")), price: @grid_price)
      @grid_pagy, page = pagy(:offset, grid_cards(grid, @states, price: @grid_price), limit: GRID_SIZE, page: page_param, querify: pages_query)
      tiles = page.pluck(:id, :card_id)
      views = Catalog::CardViews.call(tiles.map(&:first), locale: I18n.locale)
      held = Game::HeldGames.editions(grid_owner, card_ids: tiles.map(&:last), season: @season)
      prices = @grid_price.active? ? Game::Market::CollectionPrices.for_cards(tiles, owner: grid_owner) : {}
      reserved = grid_reserved(tiles.map(&:last))
      @slots = tiles.filter_map { |id, card_id| [ views[id], held[card_id], prices[card_id], reserved[card_id] ] if views.key?(id) }
      @seen_up_to = held.values.select(&:new).map(&:gained_at).max unless grid_another?
    end

    def grid_reserved(card_ids)
      grid_another? ? {} : Game::ReservedCopies.call(grid_owner, card_ids:)
    end

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

    def shown_watermark
      Game::CollectionWatermark.call(current_player) || NOTHING_SEEN
    end

    def load_summary
      @games_by_rarity = Game::HeldGames.by_rarity(grid_owner)
      @unique = @games_by_rarity.values.sum
      @season_cards = Catalog::CardCount.call(@season)
      @tier_counts = Game::TierCounts.call(grid_owner)
      @duplicates = Game::ReservedCopies.duplicates(grid_owner)
    end

    def page_param
      params[:page].to_s.to_i.clamp(1, MAX_PAGE)
    end
end

module GrandInventoryGrid
  extend ActiveSupport::Concern

  include CollectionGridLoading

  INVENTORY_LISTS = %i[rarity sets genre].freeze

  private
    def inventory_scope(source)
      source[:seasons] == "current" ? :current : :all
    end

    def inventory_filters(inventory, source)
      Catalog::CollectionGrid.call(season: inventory.season, genres: grid_list(source, :genre), rarities: grid_list(source, :rarity),
        sets: grid_list(source, :sets), query: grid_query(source), locale: I18n.locale)
    end

    def inventory_states(source)
      Game::GrandInventory.states(grid_list(source, :state), viewer: current_player)
    end

    def inventory_cards(inventory, filters, source)
      inventory.cards_in_order(filters.card_seasons, states: inventory_states(source), viewer: current_player)
    end

    def inventory_context(inventory, source)
      states = inventory_states(source)
      lists = INVENTORY_LISTS.to_h { [ it, grid_list(source, it) ] }
      { seasons: ("current" if inventory.scope == :current), state: (states unless states == [ Game::GrandInventory::DEFAULT_STATE ]),
        **lists, q: grid_query(source) }.compact_blank
    end
end

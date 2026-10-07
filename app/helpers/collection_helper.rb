# The links of the collection screen (CAP-6; DESIGN.md, Collection): the
# whole season and its sets by the kind listed and the list's page, the
# way to clear the filters and the grid's page links. Defaults are left out
# of the URLs: the tomes, the first page.
module CollectionHelper
  # The pages of the grid's links around the current one: the first, the
  # last, the current and its neighbours, :gap where pages are skipped.
  #
  #   collection_pages(pagy) # => [ 1, :gap, 4, 5, 6, :gap, 12 ]
  def collection_pages(pagy)
    current = pagy.page.clamp(1, pagy.last)
    pages = [ 1, current - 1, current, current + 1, pagy.last ].select { |page| page.between?(1, pagy.last) }.uniq.sort
    pages.each_with_object([]) do |page, series|
      series << :gap if series.any? && page > series.last + 1
      series << page
    end
  end

  # The whole season, with the sets of `kind` on page `shelf` beside it.
  def collection_season_path(kind:, shelf: 1)
    library_path(collection_list_params(kind:, shelf:))
  end

  # One set, with the sets of its kind on page `shelf` beside it.
  def collection_set_path(kind:, key:, shelf: 1)
    library_set_path(kind:, key:, **collection_list_params(kind:, shelf:).except(:kind))
  end

  # The number of filters on, as the FILTRES zone shows it: every chip
  # chosen in the rarity, set and genre groups, and the states when the
  # player chose others than the default the page opens on (the owned
  # cards, or every slot for a viewer who owns none).
  def collection_filter_count(grid:, states:, states_asked:, state_default: "owned")
    chosen = grid.chosen_rarities.size + grid.chosen_sets.size + grid.chosen_genres.size
    chosen + (states_asked && states != [ state_default ] ? states.size : 0)
  end

  # The scope with no filter and no search, the list of sets kept.
  def collection_clear_path(kind:, shelf:, set:)
    set ? collection_set_path(kind: set.kind, key: set.key, shelf:) : collection_season_path(kind:, shelf:)
  end

  private
    def collection_list_params(kind:, shelf:)
      { kind: (kind unless kind == ShelfLoading::KINDS.first), shelf: (shelf if shelf > 1) }.compact
    end
end

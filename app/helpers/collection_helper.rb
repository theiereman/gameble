# The figures of the collection's grid: its page links and the count of
# filters on.
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

  # The number of filters on, as the FILTRES zone shows it: every chip
  # chosen in the rarity, set and genre groups, and the states when the
  # player chose others than the default the page opens on, every slot.
  def collection_filter_count(filters:, states:, states_asked:)
    chosen = filters.chosen_rarities.size + filters.chosen_sets.size + filters.chosen_genres.size
    chosen + (states_asked && states != [ Game::CollectionStates::DEFAULT ] ? states.size : 0)
  end
end

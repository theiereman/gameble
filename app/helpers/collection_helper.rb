module CollectionHelper
  def collection_pages(pagy)
    current = pagy.page.clamp(1, pagy.last)
    pages = [ 1, current - 1, current, current + 1, pagy.last ].select { |page| page.between?(1, pagy.last) }.uniq.sort
    pages.each_with_object([]) do |page, series|
      series << :gap if series.any? && page > series.last + 1
      series << page
    end
  end

  def collection_filter_count(filters:, states:, states_asked:)
    chosen = filters.chosen_rarities.size + filters.chosen_sets.size + filters.chosen_genres.size
    chosen + (states_asked && states != [ Game::CollectionStates::DEFAULT ] ? states.size : 0)
  end
end

module CollectionHelper
  def collection_pages(pagy)
    current = pagy.page.clamp(1, pagy.last)
    pages = [ 1, current - 1, current, current + 1, pagy.last ].select { |page| page.between?(1, pagy.last) }.uniq.sort
    pages.each_with_object([]) do |page, series|
      series << :gap if series.any? && page > series.last + 1
      series << page
    end
  end

  def collection_filter_count(filters:, states:, states_asked:, goals: [])
    chosen = filters.chosen_rarities.size + filters.chosen_sets.size + filters.chosen_genres.size + goals.size
    chosen + (states_asked && states != [ Game::CollectionStates::DEFAULT ] ? states.size : 0)
  end

  QUICK_FILTER_IGNORED = %i[seen brother].freeze

  def quick_filters_sheet_id = "quick-filters"

  def quick_filter_current?(context, filter)
    context.except(*QUICK_FILTER_IGNORED).compact_blank == filter
  end

  def quick_filter_link(context, filter = {}, label: nil, goal: false, &text)
    link_to library_cards_path(filter), class: class_names("filter-chip", "filter-chip--goal": goal), data: { turbo_frame: "_top" },
      aria: { current: ("true" if quick_filter_current?(context, filter)), label: } do
      tag.span(class: "filter-chip__text", &text)
    end
  end
end

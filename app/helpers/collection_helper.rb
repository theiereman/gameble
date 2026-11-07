module CollectionHelper
  FILTER_ROW = { goals: %i[goals], rarity: %i[rarity], state: %i[state], more: %i[sets genre] }.freeze

  def collection_pages(pagy)
    current = pagy.page.clamp(1, pagy.last)
    pages = [ 1, current - 1, current, current + 1, pagy.last ].select { |page| page.between?(1, pagy.last) }.uniq.sort
    pages.each_with_object([]) do |page, series|
      series << :gap if series.any? && page > series.last + 1
      series << page
    end
  end

  def collection_filter_counts(filters:, states:, states_asked:, goals: [])
    {
      state: states_asked && states != [ Game::CollectionStates::DEFAULT ] ? states.size : 0,
      goals: goals.size,
      rarity: filters.chosen_rarities.size,
      sets: filters.chosen_sets.size,
      genre: filters.chosen_genres.size
    }
  end

  def filter_row_pastilles(goals:, state_choices:, sets_offered:, genres:)
    offered = { goals: goals.any?, rarity: true, state: state_choices.any?, more: sets_offered || genres.any? }
    FILTER_ROW.keys.select { offered.fetch(it) }
  end

  def filter_row_count(counts, pastille) = FILTER_ROW.fetch(pastille).sum { counts.fetch(it) }

  def filter_row_groups(pastille) = FILTER_ROW.fetch(pastille).join(" ")

  def filter_sheet_id(pastille) = "filters-#{pastille}"

  def filter_row_label(pastille) = pastille == :more ? t("library.filter_row.more") : t("library.filters.groups.#{pastille}")

  def filter_sheet_title(pastille) = pastille == :more ? t("library.filter_row.more_title") : t("library.filters.groups.#{pastille}")
end

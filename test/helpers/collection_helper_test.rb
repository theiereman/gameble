require "test_helper"

class CollectionHelperTest < ActionView::TestCase
  Page = Data.define(:page, :last)
  Grid = Data.define(:chosen_rarities, :chosen_sets, :chosen_genres)

  setup { controller.request.path_parameters[:locale] = "en" }

  def price_choice(**values) = Game::Market::CollectionPrices::Choice.new(**values)

  test "the page links keep the first, the last and the current page's neighbours, with gaps between" do
    assert_equal [ 1, :gap, 4, 5, 6, :gap, 12 ], collection_pages(Page.new(page: 5, last: 12))
    assert_equal [ 1, 2 ], collection_pages(Page.new(page: 1, last: 2))
    assert_equal [ 1, :gap, 8, 9 ], collection_pages(Page.new(page: 12, last: 9))
  end

  test "the filter row counts each group apart: goals, rarity, state, then set and genre under More" do
    grid = Grid.new(chosen_rarities: %w[rare], chosen_sets: [ :roguelike, :halo ], chosen_genres: %w[rpg])
    counts = collection_filter_counts(filters: grid, states: %w[missing], states_asked: true, goals: [ :valve ])

    assert_equal({ state: 1, goals: 1, rarity: 1, sets: 2, genre: 1, price: 0 }, counts)
    assert_equal [ 1, 1, 1, 3 ], %i[goals rarity state more].map { filter_row_count(counts, it) }
    assert_equal 0, collection_filter_counts(filters: grid, states: [ Game::CollectionStates::DEFAULT ], states_asked: true)[:state]
    assert_equal 0, collection_filter_counts(filters: grid, states: %w[owned], states_asked: false)[:state]
    assert_equal 3, collection_filter_counts(filters: grid, states: %w[owned], states_asked: false, price: price_choice(sort: "price_desc", minimum: 10, maximum: 20))[:price]
    assert_equal "sets genre", filter_row_groups(:more)
    assert_equal "filters-more", filter_sheet_id(:more)
  end

  test "the filter row offers a pastille only for a group the list has" do
    goals = Data.define(:any?).new(any?: true)
    none = Data.define(:any?).new(any?: false)

    assert_equal %i[goals rarity state more], filter_row_pastilles(goals:, state_choices: %w[all], sets_offered: true, genres: [])
    assert_equal %i[rarity state more], filter_row_pastilles(goals: none, state_choices: %w[all], sets_offered: false, genres: %w[rpg])
    assert_equal %i[rarity], filter_row_pastilles(goals: none, state_choices: [], sets_offered: false, genres: [])
    assert_equal %i[rarity state price more], filter_row_pastilles(goals: none, state_choices: %w[all], sets_offered: true, genres: [], price_offered: true)
    assert_equal [ "Goals", "Rarity", "State", "More" ], %i[goals rarity state more].map { filter_row_label(it) }
    assert_equal [ "Rarity", "More filters" ], %i[rarity more].map { filter_sheet_title(it) }
  end
end

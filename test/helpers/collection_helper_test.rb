require "test_helper"

class CollectionHelperTest < ActionView::TestCase
  Page = Data.define(:page, :last)
  Grid = Data.define(:chosen_rarities, :chosen_sets, :chosen_genres)

  test "the page links keep the first, the last and the current page's neighbours, with gaps between" do
    assert_equal [ 1, :gap, 4, 5, 6, :gap, 12 ], collection_pages(Page.new(page: 5, last: 12))
    assert_equal [ 1, 2 ], collection_pages(Page.new(page: 1, last: 2))
    assert_equal [ 1, :gap, 8, 9 ], collection_pages(Page.new(page: 12, last: 9))
  end

  test "the filter count adds the chosen chips, and the states only when they are not the default" do
    grid = Grid.new(chosen_rarities: %w[rare], chosen_sets: [ :roguelike, :halo ], chosen_genres: [])

    assert_equal 3, collection_filter_count(grid:, states: [ Game::CollectionStates::DEFAULT ], states_asked: true)
    assert_equal 5, collection_filter_count(grid:, states: %w[owned new], states_asked: true)
    assert_equal 3, collection_filter_count(grid:, states: %w[owned], states_asked: false)
  end
end

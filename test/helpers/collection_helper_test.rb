require "test_helper"

class CollectionHelperTest < ActionView::TestCase
  Page = Data.define(:page, :last)
  Grid = Data.define(:chosen_rarities, :chosen_sets, :chosen_genres)

  setup { controller.request.path_parameters[:locale] = "en" }

  test "the page links keep the first, the last and the current page's neighbours, with gaps between" do
    assert_equal [ 1, :gap, 4, 5, 6, :gap, 12 ], collection_pages(Page.new(page: 5, last: 12))
    assert_equal [ 1, 2 ], collection_pages(Page.new(page: 1, last: 2))
    assert_equal [ 1, :gap, 8, 9 ], collection_pages(Page.new(page: 12, last: 9))
  end

  test "the filter count adds the chosen chips, and the states only when they are not the default" do
    grid = Grid.new(chosen_rarities: %w[rare], chosen_sets: [ :roguelike, :halo ], chosen_genres: [])

    assert_equal 3, collection_filter_count(filters: grid, states: [ Game::CollectionStates::DEFAULT ], states_asked: true)
    assert_equal 5, collection_filter_count(filters: grid, states: %w[owned new], states_asked: true)
    assert_equal 3, collection_filter_count(filters: grid, states: %w[owned], states_asked: false)
  end

  test "a quick filter is current when the list's filters are exactly that one, the search left empty" do
    assert quick_filter_current?({ state: %w[missing], q: "" }, { state: %w[missing] })
    assert quick_filter_current?({ q: "", seen: "2026-11-03T00:00:00.000000Z" }, {})
    assert quick_filter_current?({ rarity: %w[rare], q: "", brother: "token" }, { rarity: %w[rare] })
    assert_not quick_filter_current?({ state: %w[missing], rarity: %w[rare], q: "" }, { state: %w[missing] })
    assert_not quick_filter_current?({ state: %w[missing], q: "portal" }, { state: %w[missing] })
    assert_not quick_filter_current?({ state: %w[owned missing], q: "" }, { state: %w[missing] })
  end

  test "a quick filter links to the card list with that filter alone, outside the results frame" do
    link = Nokogiri::HTML5.fragment(quick_filter_link({ q: "" }, { rarity: %w[rare] }) { "Rare" }).at_css("a")

    assert_equal "/en/library/cards?rarity%5B%5D=rare", link["href"]
    assert_equal [ "filter-chip", "_top", nil ], [ link["class"], link["data-turbo-frame"], link["aria-current"] ]
    assert_equal "Rare", link.at_css("span.filter-chip__text").text
  end
end

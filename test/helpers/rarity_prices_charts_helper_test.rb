require "test_helper"

class RarityPricesChartsHelperTest < ActionView::TestCase
  include ChartWordsHelper
  include PicoinsHelper
  include ReactorChartsHelper
  include RarityPricesChartsHelper

  def prices(epic: [ 1.0, nil, 1.43 ], common: [ nil, nil, 0.25 ])
    days = [ Date.new(2026, 11, 7), Date.new(2026, 11, 8), Date.new(2026, 11, 9) ]
    of_income = { common:, uncommon: [ nil, nil, nil ], rare: [ nil, nil, nil ], epic:, legendary: [ nil, nil, nil ] }
    Game::Market::EconomySeries::RarityPrices.of(days, of_income)
  end

  def text(html) = Nokogiri::HTML5.fragment(html.to_s).at_css("[aria-hidden=true]")&.text || html.to_s

  test "each rarity gets a tile with its price in days of capsules, its 90-day change and a sparkline from two points" do
    epic, common, uncommon = rarity_price_tiles(prices).values_at(3, 0, 1)

    assert_equal [ "Epic", 4 ], [ epic.name, epic.tier ]
    assert_equal "1.4 d", text(epic.price)
    assert_includes epic.change, "+43%"
    assert_includes epic.change, "in 90 d"
    assert_equal({ epic: [ 1.0, nil, 1.43 ] }, epic.sparkline.series)
    assert_equal "6 h 00", text(common.price)
    assert_nil common.sparkline
    assert_equal "—", text(uncommon.price)
  end

  test "the index chart has one series and table column per rarity, its legend the shape, name and last value" do
    drawing = rarity_index_drawing(prices)

    assert_equal "rarity_index", drawing.kind
    assert_equal %i[common uncommon rare epic legendary], drawing.series.keys
    assert_equal [ 100.0, nil, 143.0 ], drawing.series[:epic]
    assert_equal [ "Day", "Common", "Uncommon", "Rare", "Epic", "Legendary" ], drawing.table.columns
    assert_includes drawing.table.caption, "base 100"
    assert_equal [ :epic, "Epic · 143", 4 ], drawing.legend[3]
    assert_equal [ :uncommon, "Uncommon", 2 ], drawing.legend[1]
    assert_equal "Epic cards cost 1.4 days of capsules; their index is at 143, the highest of the five.", drawing.summary
  end

  test "without any price the summary says so" do
    empty = prices(epic: [ nil, nil, nil ], common: [ nil, nil, nil ])

    assert_equal "No price yet.", rarity_index_drawing(empty).summary
  end
end

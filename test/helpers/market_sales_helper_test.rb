require "test_helper"
require_relative "../support/market"

class MarketSalesHelperTest < ActionView::TestCase
  include MarketSettings
  include ScreenWiringHelper
  include PicoinsHelper
  include AveragePriceHelper

  setup do
    Game::Market::Settings.delete_all
    @settings = open_market!
  end

  test "the durations carry the labels of the settings and check the one asked" do
    durations = sale_durations(@settings, checked: "24")

    assert_equal [ 12, 24, 72 ], durations.map { it[:hours] }
    assert_equal [ "12 H", "24 H", "3 DAYS" ], durations.map { it[:label] }
    assert_equal [ false, true, false ], durations.map { it[:checked] }
  end

  test "no duration is checked when none is asked" do
    assert_equal [ false, false, false ], sale_durations(@settings, checked: "").map { it[:checked] }
  end

  test "the durations are labelled in French" do
    I18n.with_locale(:fr) do
      assert_equal [ "12 H", "24 H", "3 JOURS" ], sale_durations(@settings, checked: "24").map { it[:label] }
    end
  end

  test "each refusal of the operation lands in its slot" do
    {
      start_below_minimum: :starting_price,
      stamp_not_covered: :stamp, invalid_duration: :duration, copy_not_free: :grid, no_rarity: :grid,
      market_closed: :closed, player_required: :signed_out, amounts_changed: :form, market_busy: :form
    }.each do |code, slot|
      assert_equal slot, sale_refusal_slot(code), code.to_s
    end
  end

  test "an invalid price lands at the field that failed, the start by default" do
    assert_equal :starting_price, sale_refusal_slot(:invalid_price)
    assert_equal :starting_price, sale_refusal_slot(:invalid_price, invalid_price_at: :starting_price)
  end

  test "a code with no dedicated place falls back to the form" do
    assert_equal :form, sale_refusal_slot(:something_new)
  end

  test "every failure code of the operation has a message in both languages" do
    codes = %i[amounts_changed copy_not_free invalid_duration invalid_price market_busy
               market_closed no_rarity player_required stamp_not_covered start_below_minimum]
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        codes.each do |code|
          assert I18n.exists?("errors.game.#{code}"), "#{locale} #{code}"
          assert_not_empty Game::Market::ListCard.failure_message(code, amount: "1", rarity: "rare")
        end
      end
    end
  end

  test "the rarity reads in lower case in each language" do
    assert_equal "rare", sale_rarity_name(:rare)
    I18n.with_locale(:fr) { assert_equal "légendaire", sale_rarity_name(:legendary) }
  end

  test "the cell label names the card, its rarity, season, free copies and minimum" do
    card = Catalog::CardView.new(id: "portal", title: "Portal", publisher: nil, year: 2007, season_number: 1, rarity: "rare", image_url: nil, number: 1, genre: nil)
    copy = Game::Market::SellableCopies::Copy.new(ref: "portal:1", card:, free: 2, reserved: 0)

    assert_equal "Portal, Rare, Season 1, 2 available, minimum 7,800 PiCoins", sale_cell_label(copy, @settings)
  end

  test "the cell label ends with the edition's price words when there is a price" do
    card = Catalog::CardView.new(id: "portal", title: "Portal", publisher: nil, year: 2007, season_number: 1, rarity: "rare", image_url: nil, number: 1, genre: nil)
    copy = Game::Market::SellableCopies::Copy.new(ref: "portal:1", card:, free: 2, reserved: 0)
    price = Game::Market::EditionPrices::Price.new(average: 15_000, sales_used: 5)

    assert_equal "Portal, Rare, Season 1, 2 available, minimum 7,800 PiCoins, average price 15,000 PiCoins", sale_cell_label(copy, @settings, price)
  end

  test "the root data wires the screen's controllers and its settings" do
    data = sale_root_data(open: true, basis_points: 1_000)

    assert_equal "listing-form", data[:controller]
    assert_equal 1_000, data[:listing_form_basis_points_value]
    assert_equal "#listing-form [data-controller~='listing-grid']", data[:listing_form_listing_grid_outlet]
    assert_includes data[:action], "listing-grid:chosen->listing-form#chosen"
    assert_includes data[:action], "submit->listing-form#submit"
    assert_equal "At least %{amount} for a %{rarity}", data[:listing_form_strings_value]["minimumHint"]
  end
end

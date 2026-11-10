require "test_helper"

class MarketHelperTest < ActionView::TestCase
  include PicoinsHelper
  include LocalTimeHelper

  def wording(seconds, locale) = I18n.with_locale(locale) { listing_time_left(seconds) }

  test "under a minute reads in the last minute" do
    assert_equal "under a minute", wording(59, :en)
    assert_equal "moins d'une minute", wording(59, :fr)
    assert_equal "under a minute", wording(0, :en)
  end

  test "from sixty seconds it reads whole minutes" do
    assert_equal "1 min", wording(60, :en)
    assert_equal "59 min", wording(59 * 60, :en)
    assert_equal "59 min", wording(59 * 60, :fr)
  end

  test "from an hour it reads hours and padded minutes" do
    assert_equal "2 h 14", wording(134 * 60, :en)
    assert_equal "2 h 14", wording(134 * 60, :fr)
    assert_equal "1 h 05", wording(65 * 60, :en)
  end

  test "under an hour is soon" do
    assert time_left_soon?(3599)
    assert_not time_left_soon?(3600)
  end

  test "the seconds left are floored and never negative" do
    travel_to(Time.utc(2026, 11, 10, 12)) do
      assert_equal 90, listing_seconds_left(Time.utc(2026, 11, 10, 12, 1, 30.9))
      assert_equal 0, listing_seconds_left(Time.utc(2026, 11, 10, 11))
    end
  end

  test "the sorts are the four of the market" do
    assert_equal %w[ending price_asc price_desc newest], sort_options
  end

  test "the clock data carries the server's words as templates" do
    data = I18n.with_locale(:fr) { clock_data(120) }

    assert_equal "listing-clock", data[:controller]
    assert_equal 120, data[:listing_clock_seconds_value]
    assert_equal "%{hours} h %{minutes}", data[:listing_clock_hours_template_value]
    assert_equal "moins d'une minute", data[:listing_clock_under_template_value]
  end

  test "the tile label names card, rarity, season, price, offers, end and buy-now" do
    card = Catalog::CardViews.call([ catalog_card_seasons(:rare_card_one).id ], locale: :en).values.first
    row = Game::Market::OpenListings::Row.new(token: "t", card:, current_price: 9_000, buy_now_price: nil, ends_at: Time.utc(2026, 11, 10, 22, 14), offers: 1)

    label = I18n.with_locale(:en) { listing_tile_label(row) }

    assert_match(/\ABlue Depths, Rare, season 1, 9,000 PiCoins, 1 offer, ends at .+\z/, label)
    assert_no_match(/buy now/, label)
  end
end

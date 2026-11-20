require "test_helper"
require_relative "../../../support/market"

class Game::Market::SettingsTest < ActiveSupport::TestCase
  include MarketSettings

  setup { Game::Market::Settings.delete_all }

  test "a new version prices the slots at their defaults and no rarity in the Archives" do
    settings = open_market!

    assert_equal [ 500, 1_000, 2_000, 3_000, 5_000 ], (6..10).map { settings.slot_price(:goal, it) }
    assert_equal [ 500, 1_000, 2_000, 3_000, 5_000 ], (6..10).map { settings.slot_price(:custom_set, it) }
    assert_equal [ 1_000, 2_000 ], (4..5).map { settings.slot_price(:deck, it) }
    assert_equal [ nil ] * 5, Game::Market::SettingsRules::RARITIES.map { settings.archive_price(it) }
  end

  test "the Archive price reads its rarity's column" do
    assert_equal 500, open_market!(archive_price_rare: 500).archive_price(:rare)
  end

  test "a slot outside the priced ones, or an unknown kind, has no price" do
    settings = open_market!

    assert_raises(ArgumentError) { settings.slot_price(:goal, 5) }
    assert_raises(ArgumentError) { settings.slot_price(:goal, 11) }
    assert_raises(ArgumentError) { settings.slot_price(:deck, 6) }
    assert_raises(ArgumentError) { settings.slot_price(:binder, 6) }
  end

  test "the database refuses an Archive price under its rarity's minimum" do
    assert_raises(ActiveRecord::StatementInvalid) { open_market!(archive_price_rare: 77) }
  end
end

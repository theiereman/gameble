require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"

class Game::Market::EntrustableCopiesTest < ActiveSupport::TestCase
  include Holdings
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @settings = open_market!
  end

  test "it lists the unreserved copies of editions with a rarity, most valuable first, with their value" do
    hold(@player, @common.id, 3)
    hold(@player, @rare.id, 2, reserved: 1)
    hold(@player, catalog_card_seasons(:uncommon_card_one).id, 1, reserved: 1)

    copies = Game::Market::EntrustableCopies.call(@player, settings: @settings, locale: :en)

    assert_equal [ :rare, :common ], copies.map(&:rarity)
    assert_equal [ 1, 3 ], copies.map(&:free)
    assert_equal [ 2, 3 ], copies.map(&:owned)
    assert_equal [ 5_000, 1_000 ], copies.map(&:value)
    assert_equal [ "#{@rare.card.slug}:#{@rare.season.number}", "#{@common.card.slug}:#{@common.season.number}" ], copies.map(&:ref)
  end

  test "refs resolve to card-season ids, and an unknown ref is left out" do
    refs = [ "#{@rare.card.slug}:#{@rare.season.number}", "nothing:1", "malformed" ]

    assert_equal({ refs.first => @rare.id }, Game::Market::EntrustableCopies.resolve(refs))
  end
end

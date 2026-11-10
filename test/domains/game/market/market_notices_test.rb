require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"

class Game::Market::MarketNoticesTest < ActiveSupport::TestCase
  include Holdings
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @reader = accounts_players(:moderator)
    @other = accounts_players(:administrator)
    @other.update_columns(persona_name: "Max")
    @card = catalog_card_seasons(:rare_card_one)
    hold(@seller, @card.id, 8, reserved: 8)
    open_market!
  end

  def listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)

  def notice(player, listing, at:, kind: "outbid")
    Game::Market::Notice.record(player_id: player.id, listing_id: listing.id, kind:, other_player_id: @other.id, amount: 5_000, at:)
  end

  test "a player's notices come newest first with the card, the other player and the amount" do
    older = listing
    newer = listing
    notice(@reader, older, at: 2.hours.ago)
    notice(@reader, newer, at: 1.hour.ago)

    lines = Game::Market::MarketNotices.call(player: @reader, locale: :en)

    assert_equal [ newer.token, older.token ], lines.map(&:token)
    first = lines.first
    assert_equal [ :outbid, "Blue Depths", @other, 5_000 ], [ first.kind, first.card, first.other, first.amount ]
  end

  test "another player never reads them" do
    notice(@reader, listing, at: 1.hour.ago)

    assert_empty Game::Market::MarketNotices.call(player: @other, locale: :en)
  end

  test "the outbid lines of the given listings leave out other kinds, other listings and other players" do
    outbid = listing
    won = listing
    elsewhere = listing
    notice(@reader, outbid, at: 2.hours.ago)
    notice(@reader, won, at: 1.hour.ago, kind: "won")
    notice(@reader, elsewhere, at: 1.hour.ago)
    notice(@other, outbid, at: 1.hour.ago)

    lines = Game::Market::MarketNotices.outbid(player: @reader, listing_ids: [ outbid.id, won.id ], locale: :en)

    assert_equal [ outbid.token ], lines.map(&:token)
  end

  test "at most five come back, the newest" do
    listings = Array.new(6) { listing }
    listings.each_with_index { |listing, index| notice(@reader, listing, at: index.hours.ago) }

    lines = Game::Market::MarketNotices.call(player: @reader, locale: :en)

    assert_equal listings.first(5).map(&:token), lines.map(&:token)
  end
end

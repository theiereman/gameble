require "test_helper"
require_relative "../../../support/custom_sets"
require_relative "../../../support/game_sets"
require_relative "../../../support/holdings"
require_relative "../../../support/market"

class Game::Market::WantedNoticesTest < ActiveSupport::TestCase
  include CustomSets
  include GameSets
  include Holdings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @wanting = accounts_players(:moderator)
    @holder = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    @settings = open_market!
    Game::Market::Mint.credit(player_id: @seller.id, amount: 1_000, settings_id: @settings.id)
    hold(@seller, @card.id, 2)
    insert_set([ @card.id, *unheld_cards(2) ], { complete: 3 }, key: "roguelike", params: { "theme" => "roguelike" })
  end

  def aim(player) = Game::AddGoal.new.call(player:, kind: "theme", key: "roguelike").value!

  def list(starting_price: @settings.minimum_price_common)
    Game::Market::ListCard.new.call(player: @seller, card_season_id: @card.id, starting_price:, duration_hours: 24, settings_token: @settings.token).value!
  end

  def wanted = Game::Market::Notice.where(kind: "wanted").order(:player_id)

  test "listing a card notices each player whose goal misses it, with the starting price" do
    aim(@wanting)
    listing = list(starting_price: @settings.minimum_price_common + 500)

    notice = wanted.sole
    assert_equal [ @wanting.id, listing.id, @settings.minimum_price_common + 500 ], [ notice.player_id, notice.listing_id, notice.amount ]
  end

  test "a player who holds the card, the seller and a removed player are not noticed" do
    [ @wanting, @holder, @seller ].each { aim(it) }
    Game::Goal.create!(player_id: accounts_players(:banned).id, position: 1, set_kind: "theme", set_key: "roguelike")
    hold(@holder, @card.id, 1)

    list

    assert_equal [ @wanting.id ], wanted.pluck(:player_id)
  end

  test "a goal on a custom set holding the card notices its player too" do
    Game::AddGoal.new.call(player: @wanting, custom_set: create_custom_set(@wanting, card_ids: [ @card.card_id, *fixture_card_ids.excluding(@card.card_id).first(2) ]).token).value!

    list

    assert_equal [ @wanting.id ], wanted.pluck(:player_id)
  end

  test "a card no goal aims at notices nobody" do
    list

    assert_empty wanted
  end

  test "a player is first in for a push only without another wanted card noticed within the quiet hour" do
    aim(@wanting)
    aim(@holder)
    earlier = travel_to(30.minutes.ago) { list }
    Game::Market::Notice.where(player_id: @holder.id, listing_id: earlier.id).update_all(noticed_at: 2.hours.ago)
    listing = list

    listed = Game::Market::WantedNoticePlayers.first_in(listing.id, quiet_for: 1.hour)
    assert_equal [ listing.token, @card.id, [ @holder.id ] ], [ listed.token, listed.card_season_id, listed.player_ids ]
  end
end

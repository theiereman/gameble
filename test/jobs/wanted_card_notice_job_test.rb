require "test_helper"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/singleton_stub"

class WantedCardNoticeJobTest < ActiveJob::TestCase
  include GameSets
  include Holdings
  include MarketSettings
  include SingletonStub

  setup do
    @seller = accounts_players(:player)
    @wanting = accounts_players(:moderator)
    @card = catalog_card_seasons(:common_card_one)
    @settings = open_market!
    Game::Market::Mint.credit(player_id: @seller.id, amount: 1_000, settings_id: @settings.id)
    hold(@seller, @card.id, 2)
    insert_set([ @card.id, *unheld_cards(2) ], { complete: 3 }, key: "roguelike", params: { "theme" => "roguelike" })
    Game::AddGoal.new.call(player: @wanting, kind: "theme", key: "roguelike").value!
    @phone = Accounts::RegisterPushDevice.new.call(player: @wanting, platform: "apple", token: "wanting-phone", locale: "en").value!
  end

  def list = Game::Market::ListCard.new.call(player: @seller, card_season_id: @card.id, starting_price: @settings.minimum_price_common,
    duration_hours: 24, settings_token: @settings.token).value!

  def pushes = enqueued_jobs.select { it[:job] == ApplicationPushNotificationJob }

  def perform_configured(listing)
    stub_singleton(PushNotices, :deliverable?, ->(_device) { true }) { WantedCardNoticeJob.perform_now(listing.id) }
  end

  test "listing a wanted card enqueues the notice once the listing commits, and the job pushes it to the player's devices" do
    listing = list

    assert_enqueued_with(job: WantedCardNoticeJob, args: [ listing.id ])
    perform_configured(listing)
    _class_name, attributes, device = pushes.sole[:args]
    assert_match(/, missing from your goals, is on the market\.\z/, attributes["body"])
    assert_equal "A card you want is on sale", attributes["title"]
    assert_equal @phone.to_global_id.to_s, device["_aj_globalid"]
  end

  test "a second wanted card within the hour stays in the bell without a push" do
    perform_configured(list)
    clear_enqueued_jobs

    travel(20.minutes) { perform_configured(list) }

    assert_empty pushes
  end
end

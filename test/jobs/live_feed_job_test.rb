require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/game_sets"

class LiveFeedJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include GamePacks
  include GameSets

  setup do
    @hugo = accounts_players(:player)
    @hugo.update!(persona_name: "Hugo")
    @epic = fixture_tier_ids[3]
  end

  def open_pack(cards: [ @epic ] * 5)
    pack = create_pack(@hugo, cards:)
    Game::OpenPack.new.call(player: @hugo).value!
    pack
  end

  def received(locale)
    Nokogiri::HTML5.fragment(ActiveSupport::JSON.decode(broadcasts(LiveStream.feed_streamables(locale).join(":")).sole))
  end

  def template(fragment, action, target)
    Nokogiri::HTML5.fragment(fragment.css("turbo-stream[action='#{action}'][target='#{target}']").sole.at_css("template").inner_html)
  end

  test "an opening's entries go to the feed, the ticker and the strip, rendered once per locale" do
    pack = open_pack

    LiveFeedJob.perform_now([ { pack_id: pack.id } ])

    english = received(:en)
    feed = template(english, "prepend", "feed-entries")
    assert_equal 5, feed.css("li.feed__entry").size
    assert_equal "Hugo pulled Portal", feed.at_css(".feed__sentence").text
    ticker = template(english, "prepend", "live-ticker-queue")
    assert_equal 5, ticker.css("li.ticker__item").size
    assert_equal "Hugo pulled Portal", ticker.at_css(".ticker__sentence").text
    assert_equal "Epic", ticker.at_css(".ticker__rarity.ticker__rarity--epic").text
    strip = template(english, "replace", "live-strip")
    assert_equal 3, strip.css("#live-strip li.public-card__live-entry").size
    assert_empty english.css("[style]")

    assert_equal "/en/cards/portal", feed.at_css("a.feed__thumb")["href"]
    time = feed.at_css("time.feed__time[data-controller=local-time][data-local-time-style-value=datetime]")
    occurred_at = Time.iso8601(time["datetime"])
    assert_equal occurred_at.utc.strftime("%Y-%m-%d %H:%M UTC"), time.text

    french = received(:fr)
    assert_equal "Hugo a tiré Portal", template(french, "prepend", "feed-entries").at_css(".feed__sentence").text
    assert_equal "/fr/cards/portal", template(french, "prepend", "feed-entries").at_css("a.feed__thumb")["href"]
    assert_equal "Épique", template(french, "prepend", "live-ticker-queue").at_css(".ticker__rarity").text
  end

  test "a first discovery joins the ticker behind its words" do
    common = fixture_tier_ids[0]
    Game::FirstDiscovery.where(card_season_id: common).delete_all
    pack = open_pack(cards: [ common ] * 5)

    LiveFeedJob.perform_now([ { pack_id: pack.id } ])

    item = template(received(:en), "prepend", "live-ticker-queue").css("li.ticker__item").sole
    assert_equal "First discovery", item.at_css(".ticker__first").text
    assert_match(/found by Hugo for the first time/, item.at_css(".ticker__sentence").text)
  end

  test "nothing is sent when no entry is left to show" do
    pack = open_pack
    @hugo.update!(visibility: :private)

    LiveFeedJob.perform_now([ { pack_id: pack.id } ])

    assert_no_broadcasts LiveStream.feed_streamables(:en).join(":")
    assert_no_broadcasts LiveStream.feed_streamables(:fr).join(":")
  end

  # The notices the opening's events leave for the job.
  def notices = game_events(@hugo).flat_map { LiveStream.notices(it) }

  def commons = [ fixture_tier_ids[0] ] * 5

  test "a public opening that reaches silver on a theme is one set line in the feed and the ticker, with no thumbnail" do
    common, uncommon, rare, = fixture_tier_ids
    theme = insert_set([ common, uncommon, rare ], { bronze: 1, silver: 2, gold: 3 })
    Game::SetTier.insert_all!([ { player_id: @hugo.id, set_id: theme, tier: "bronze", reached_by: "trade", reached_at: 1.day.ago } ])
    Game::Holding.create!(player_id: @hugo.id, card_season_id: uncommon, quantity: 1)
    open_pack(cards: commons)

    LiveFeedJob.perform_now(notices)

    english = received(:en)
    feed = template(english, "prepend", "feed-entries")
    entry = feed.css("li.feed__entry").sole
    assert_equal "Hugo reaches silver in the Roguelike set.", entry.at_css(".feed__sentence").text
    assert_equal "Silver", entry.at_css(".feed__tag.feed__tier.feed__tier--silver").text
    assert_equal 2, entry.css(".feed__tier-notches i").size
    assert_empty entry.css(".feed__thumb, .feed__chip")
    assert entry.matches?(".feed__entry--set")
    item = template(english, "prepend", "live-ticker-queue").css("li.ticker__item").sole
    assert_equal "Hugo reaches silver in the Roguelike set.", item.at_css(".ticker__sentence").text
    assert_equal "Silver", item.at_css(".ticker__tier.feed__tier--silver").text
    assert_empty english.css("[style]")

    french = received(:fr)
    assert_equal "Hugo atteint l'argent du set Roguelike.", template(french, "prepend", "feed-entries").at_css(".feed__sentence").text
    assert_equal "Argent", template(french, "prepend", "live-ticker-queue").at_css(".ticker__tier").text
  end

  test "an opening reaching four sets' tiers is one item in the feed and the ticker, with the count and the highest" do
    insert_four_themes
    open_pack(cards: commons)
    assert_equal 6, notices.count { it.key?(:set_id) }

    LiveFeedJob.perform_now(notices)

    english = received(:en)
    feed = template(english, "prepend", "feed-entries").css("li.feed__entry").sole
    assert_equal "Hugo reaches 4 tiers · Metroidvania GOLD", feed.at_css(".feed__sentence").text
    assert_equal 3, feed.css(".feed__tier--gold .feed__tier-notches i").size
    ticker = template(english, "prepend", "live-ticker-queue").css("li.ticker__item").sole
    assert_equal "Hugo reaches 4 tiers · Metroidvania GOLD", ticker.at_css(".ticker__sentence").text
    assert_equal "Hugo atteint 4 paliers · Metroidvania OR",
      template(received(:fr), "prepend", "live-ticker-queue").at_css(".ticker__sentence").text
  end

  test "a completion reads as the set completed, behind the COMPLET frame" do
    open_pack(cards: [ @epic ] * 5)

    LiveFeedJob.perform_now(notices.select { it.key?(:set_id) })

    french = template(received(:fr), "prepend", "feed-entries").css("li.feed__entry").sole
    assert_equal "Hugo complète le set Valve.", french.at_css(".feed__sentence").text
    assert_equal "Complet", french.at_css(".feed__tag.feed__tier--complete").text
    assert french.at_css(".feed__tier--complete .feed__tier-stamp")
    assert_empty french.css(".feed__tier-notches")
  end

  test "a private player's tiers are not broadcast" do
    insert_four_themes
    @hugo.update!(visibility: :private)
    open_pack(cards: commons)

    LiveFeedJob.perform_now(notices)

    assert_no_broadcasts LiveStream.feed_streamables(:en).join(":")
    assert_no_broadcasts LiveStream.feed_streamables(:fr).join(":")
  end
end

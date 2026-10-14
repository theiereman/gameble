require "test_helper"
require_relative "../support/game_packs"

class LiveFeedJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include GamePacks

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
end

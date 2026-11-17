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

  test "each prepended entry carries a lazy reaction frame that loads the viewer's own bar, with its counters and no button" do
    pack = open_pack

    LiveFeedJob.perform_now([ { pack_id: pack.id } ])

    feed = template(received(:en), "prepend", "feed-entries")
    frames = feed.css("li.feed__entry turbo-frame.feed__reactions")
    assert_equal 5, frames.size
    token = Game::FeedEntry.find_by!(pack_id: pack.id, position: 0).token
    frame = frames.find { it["id"] == "reactions-#{token}" }
    assert_equal "lazy", frame["loading"]
    assert_equal "/en/feed/entries/#{token}/reactions", frame["src"]
    assert_equal 5, frame.css(".feed__reaction--static").size
    assert_empty frame.css("button, form")
    assert_equal [ "" ] * 5, frame.css(".feed__reaction-count").map(&:text)
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
    assert_empty ticker.css(".ticker__sentence a")
    assert_equal "Epic", ticker.at_css(".ticker__rarity.ticker__rarity--epic").text
    strip = template(english, "replace", "live-strip")
    assert_equal 3, strip.css("#live-strip li.live-strip__entry").size
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
    rare = fixture_tier_ids[2]
    Game::FirstDiscovery.where(card_season_id: rare).delete_all
    pack = open_pack(cards: [ rare ] * 5)

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

  test "an opening of commons that reaches tiers without completing a set broadcasts nothing" do
    insert_four_themes
    open_pack(cards: commons)
    assert_empty notices.select { it.key?(:set_id) }

    assert_no_broadcasts LiveStream.feed_streamables(:en).join(":") do
      LiveFeedJob.perform_now(notices)
    end
  end

  test "an opening completing a set among other tiers is one item in the feed and the ticker, with the count and the completion" do
    insert_four_themes
    members = [ fixture_tier_ids[0], *unheld_cards(4) ]
    insert_set(members, { bronze: 1, silver: 1, gold: 5, complete: 5 }, key: "souls")
    open_pack(cards: members)
    assert_equal 1, notices.count { it.key?(:set_id) }

    LiveFeedJob.perform_now(notices)

    english = received(:en)
    feed = template(english, "prepend", "feed-entries").css("li.feed__entry").sole
    assert_equal "Hugo reaches 10 tiers · Souls COMPLETE", feed.at_css(".feed__sentence").text
    ticker = template(english, "prepend", "live-ticker-queue").css("li.ticker__item").sole
    assert_equal "Hugo reaches 10 tiers · Souls COMPLETE", ticker.at_css(".ticker__sentence").text
    assert_equal "Hugo atteint 10 paliers · Souls COMPLET",
      template(received(:fr), "prepend", "live-ticker-queue").at_css(".ticker__sentence").text
  end

  test "a completion reads as the set completed, with no tier tag repeating it" do
    open_pack(cards: [ @epic ] * 5)

    LiveFeedJob.perform_now(notices.select { it.key?(:set_id) })

    french = template(received(:fr), "prepend", "feed-entries").css("li.feed__entry").sole
    assert_equal "Hugo complète le set Valve.", french.at_css(".feed__sentence").text
    assert_equal "Complète le set", french.at_css(".feed__headline-kicker").text
    assert_empty french.css(".feed__tier")
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

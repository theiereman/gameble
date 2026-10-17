require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/game_trades"

class LiveStreamTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include ActiveJob::TestHelper
  include GamePacks
  include GameTrades

  setup do
    @hugo = accounts_players(:player)
    @hugo.update!(persona_name: "Hugo")
    @epic = fixture_tier_ids[3]
  end

  def live(locale) = LiveStream.feed_streamables(locale).join(":")

  def live_jobs = enqueued_jobs.select { it[:job] == LiveFeedJob }

  def batches = ActiveSupport::IsolatedExecutionState[LiveStream::BATCHES] || {}

  def open_pack(player = @hugo, cards: [ @epic ] * 5)
    pack = create_pack(player, cards:)
    Game::OpenPack.new.call(player:).value!
    pack
  end

  def received(locale)
    Nokogiri::HTML5.fragment(ActiveSupport::JSON.decode(broadcasts(live(locale)).sole))
  end

  test "the public streams have fixed names, one per locale, with no id" do
    assert_equal %w[live:en live:fr], I18n.available_locales.map { live(it) }
    assert_equal "goal:fr", LiveStream.goal_streamables(:fr).join(":")
  end

  test "an opening enqueues one job after its commit, naming its pack and the tiers it reached" do
    pack = nil
    assert_enqueued_jobs(1, only: LiveFeedJob) { pack = open_pack }

    valve = { player_id: @hugo.id, set_id: catalog_sets(:valve_one).id, tier: "complete" }
    assert_equal [ [ { pack_id: pack.id }, valve ] ], live_jobs.map { ActiveJob::Arguments.deserialize(it[:args]).first }
    assert_empty batches
  end

  test "the openings of one transaction leave in one job once it commits, and nothing is broadcast inside it" do
    perform_enqueued_jobs(only: LiveFeedJob) do
      ApplicationRecord.transaction do
        open_pack
        open_pack

        assert_empty live_jobs, "nothing is enqueued before the commit"
        assert_no_broadcasts live(:en)
        assert_no_broadcasts live(:fr)
      end
    end

    assert_equal 1, performed_jobs.count { it[:job] == LiveFeedJob }
    assert_broadcasts live(:en), 1
    assert_broadcasts live(:fr), 1
    # Ten pulls, and the first opening's completion of the Valve set.
    assert_equal 11, received(:en).css("turbo-stream[action=prepend][target=feed-entries] template").sole.children.count { it.element? }
    assert_empty batches
  end

  test "an opening rolled back enqueues nothing" do
    create_pack(@hugo, cards: [ @epic ] * 5)

    ApplicationRecord.transaction do
      Game::OpenPack.new.call(player: @hugo).value!
      raise ActiveRecord::Rollback
    end

    assert_empty live_jobs
    assert_empty batches
    assert_not Game::FeedEntry.exists?
  end

  test "a private player's opening is not broadcast, nor one whose player is banned before it leaves" do
    @hugo.update!(visibility: :private)
    perform_enqueued_jobs(only: LiveFeedJob) { open_pack }
    assert_no_broadcasts live(:en)

    @hugo.update!(visibility: :public)
    open_pack
    @hugo.update!(banned_at: Time.current)
    perform_enqueued_jobs(only: LiveFeedJob)
    assert_no_broadcasts live(:en)
    assert_no_broadcasts live(:fr)
  end

  test "a pack of fillers only is not broadcast" do
    perform_enqueued_jobs(only: LiveFeedJob) { open_pack(cards: [ catalog_card_seasons(:rare_card_one).id ] * 5) }

    assert Game::FeedEntry.where(notable: false).exists?
    assert_no_broadcasts live(:en)
  end

  test "a repost is prepended to the feed but never queued on the ticker" do
    Game::Holding.create!(player_id: @hugo.id, card_season_id: @epic, quantity: 1)

    perform_enqueued_jobs(only: LiveFeedJob) { Game::RepostCard.new.call(player: @hugo, card_season_id: @epic).value! }

    english = received(:en)
    feed = english.css("turbo-stream[action=prepend][target=feed-entries]").sole
    assert_equal "Hugo reposted Portal.", Nokogiri::HTML5.fragment(feed.at_css("template").inner_html).at_css(".feed__sentence").text
    assert_empty english.css("turbo-stream[target=live-ticker-queue]")
  end

  test "a repost's notice carries its player, card and time" do
    event = Game::CardReposted.new(data: { player_id: @hugo.id, card_season_id: @epic }, metadata: { timestamp: Time.utc(2026, 10, 8, 12) })

    assert_equal [ { player_id: @hugo.id, card_season_id: @epic, at: Time.utc(2026, 10, 8, 12) } ], LiveStream.notices(event)
  end

  test "a tier's notice carries its player, set and tier, a completion's tier being complete" do
    reached = Game::SetTierReached.new(data: { player_id: @hugo.id, set_id: 7, tier: "silver" })
    completed = Game::SetCompleted.new(data: { player_id: @hugo.id, set_id: 8 })

    assert_equal [ { player_id: @hugo.id, set_id: 7, tier: "silver" } ], LiveStream.notices(reached)
    assert_equal [ { player_id: @hugo.id, set_id: 8, tier: "complete" } ], LiveStream.notices(completed)
  end

  test "a public opening's completion reaches the feed, the ticker queue and the strip once" do
    perform_enqueued_jobs(only: LiveFeedJob) { open_pack }

    english = received(:en)
    assert_equal [ "Hugo completes the Valve set." ], template(english, "feed-entries").css(".feed__entry--set .feed__sentence").map(&:text)
    assert_equal [ "Hugo completes the Valve set." ], template(english, "live-ticker-queue").css(".ticker__sentence").map(&:text).grep(/Valve/)
    assert_equal "Hugo completes the Valve set.", template(english, "live-strip").at_css(".public-card__live-sentence").text
  end

  test "other events tell nothing" do
    assert_empty LiveStream.notices(Game::TradeProposed.new(data: { trade_id: 1, proposer_id: @hugo.id, recipient_id: @hugo.id }))
  end

  def trade(proposer = @hugo, recipient = @sam)
    conclude_trade(proposer, recipient, offer: { @epic => 1 }, request: { catalog_card_seasons(:rare_card_one).id => 1 })
  end

  def template(stream, target) = Nokogiri::HTML5.fragment(stream.css("turbo-stream[target=#{target}] template").sole.inner_html)

  test "a trade enqueues one job after its commit, naming its trade and the tiers it reached" do
    @sam = accounts_players(:moderator)
    accepted = nil
    assert_enqueued_jobs(1, only: LiveFeedJob) { accepted = trade }

    valve = { player_id: @sam.id, set_id: catalog_sets(:valve_one).id, tier: "complete" }
    assert_equal [ [ { trade_id: accepted.id }, valve ] ], live_jobs.map { ActiveJob::Arguments.deserialize(it[:args]).first }
    assert_empty batches
  end

  test "a public trade reaches the feed, the ticker queue and the strip, naming both players and both cards" do
    @sam = accounts_players(:moderator).tap { it.update!(persona_name: "Sam") }

    perform_enqueued_jobs(only: LiveFeedJob) { trade }

    english = received(:en)
    sentence = "Hugo and Sam traded Portal for Blue Depths"
    feed = template(english, "feed-entries")
    assert_equal sentence, feed.at_css(".feed__sentence").text
    assert_equal 2, feed.css(".feed__thumbs .feed__thumb--framed").size
    assert_equal "Trade", feed.at_css(".feed__tag--trade").text.strip
    ticker = template(english, "live-ticker-queue")
    assert_equal sentence, ticker.at_css(".ticker__sentence").text
    assert_equal "Trade", ticker.at_css(".ticker__trade").text.strip
    assert_empty ticker.css(".ticker__rarity")
    assert_equal sentence, template(english, "live-strip").at_css(".public-card__live-sentence").text
    assert_equal "Hugo et Sam ont échangé Portal contre Profondeurs bleues",
      template(received(:fr), "feed-entries").at_css(".feed__sentence").text
  end

  test "a trade is not broadcast when either of its players is hidden from a visitor" do
    @sam = accounts_players(:moderator)
    trade
    @sam.update!(visibility: :friends_only)
    perform_enqueued_jobs(only: LiveFeedJob)
    assert_no_broadcasts live(:en)

    @sam.update!(visibility: :public)
    trade(@sam, @hugo)
    @hugo.update!(banned_at: Time.current)
    perform_enqueued_jobs(only: LiveFeedJob)
    assert_no_broadcasts live(:en)
    assert_no_broadcasts live(:fr)
  end

  test "a trade rolled back enqueues nothing" do
    @sam = accounts_players(:moderator)

    ApplicationRecord.transaction do
      trade
      raise ActiveRecord::Rollback
    end

    assert_empty live_jobs
    assert_empty batches
  end

  test "a trade's notice carries its trade" do
    event = Game::TradeAccepted.new(data: { trade_id: 7, proposer_id: @hugo.id, recipient_id: @hugo.id })

    assert_equal [ { trade_id: 7 } ], LiveStream.notices(event)
  end
end

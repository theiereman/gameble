require "test_helper"
require_relative "../support/game_packs"

class LiveStreamTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include ActiveJob::TestHelper
  include GamePacks

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

  test "an opening enqueues one job after its commit, naming its pack" do
    pack = nil
    assert_enqueued_jobs(1, only: LiveFeedJob) { pack = open_pack }

    assert_equal [ [ { pack_id: pack.id } ] ], live_jobs.map { ActiveJob::Arguments.deserialize(it[:args]).first }
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
    assert_equal 10, received(:en).css("turbo-stream[action=prepend][target=feed-entries] template").sole.children.count { it.element? }
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

  test "other events tell nothing" do
    assert_empty LiveStream.notices(Game::TradeProposed.new(data: { trade_id: 1, proposer_id: @hugo.id, recipient_id: @hugo.id }))
  end
end

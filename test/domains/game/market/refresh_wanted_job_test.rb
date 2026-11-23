require "test_helper"
require_relative "../../../support/game_sets"

# An event that changes a player's wanted cards queues, once it commits, one rebuild of their rows per player it names.
class Game::Market::RefreshWantedJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GameSets

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
    @common = catalog_card_seasons(:common_card_one)
    insert_set([ @common.id ], { complete: 1 }, key: "solo", params: { "theme" => "solo" })
  end

  def hear(event) = ApplicationRecord.transaction { Game::Market::Handlers::WantedRefresh.call(event) }

  def trade(proposer, recipient) = Game::TradeAccepted.new(data: { proposer_id: proposer.id, recipient_id: recipient.id })

  def pending = Game::Market::PendingWantedRefresh.order(:player_id).pluck(:player_id)

  def every_key_data
    { player_id: @player.id, proposer_id: @player.id, recipient_id: @other.id, seller_id: @player.id, winner_id: @other.id,
      buyer_id: @other.id, goal_id: 1, sales: [ { buyer_id: @other.id } ] }
  end

  test "every heard event queues, once it commits, one refresh per player it names" do
    Game::Market::Handlers::WantedRefresh::EVENTS.each do |event_class|
      event = event_class.new(data: every_key_data)
      named = Game::Handlers::NamedPlayers.of(event, Game::Market::Handlers::WantedRefresh::PLAYERS)

      assert_enqueued_jobs(named.size, only: Game::Market::RefreshWantedJob) { hear(event) }
      named.each { assert_enqueued_with(job: Game::Market::RefreshWantedJob, args: [ it ]) }
      clear_enqueued_jobs
      Game::Market::PendingWantedRefresh.delete_all
    end
  end

  test "a trade queues a refresh for each of its two players" do
    hear(trade(@player, @other))

    assert_enqueued_with(job: Game::Market::RefreshWantedJob, args: [ @player.id ])
    assert_enqueued_with(job: Game::Market::RefreshWantedJob, args: [ @other.id ])
    assert_equal [ @player.id, @other.id ].sort, pending
  end

  test "a rolled back event queues nothing and leaves nothing pending" do
    assert_no_enqueued_jobs(only: Game::Market::RefreshWantedJob) do
      ApplicationRecord.transaction do
        Game::Market::Handlers::WantedRefresh.call(trade(@player, @other))
        raise ActiveRecord::Rollback
      end
    end

    assert_empty pending
  end

  test "a pending refresh is not doubled, and once it ran the next event queues another" do
    hear(trade(@player, @other))

    assert_no_enqueued_jobs(only: Game::Market::RefreshWantedJob) { hear(trade(@other, @player)) }

    perform_enqueued_jobs(only: Game::Market::RefreshWantedJob)
    assert_empty pending

    assert_enqueued_jobs(2, only: Game::Market::RefreshWantedJob) { hear(trade(@other, @player)) }
  end

  test "a removed player gets no refresh" do
    banned = accounts_players(:banned)
    deleted = Accounts::Player.create!(deleted_at: 1.day.ago)

    assert_enqueued_jobs(1, only: Game::Market::RefreshWantedJob) do
      hear(trade(banned, @player))
      hear(trade(deleted, @player))
    end
    assert_equal [ @player.id ], pending
  end

  test "the job rebuilds the player's rows under their bank lock and clears their pending refresh" do
    Game::Goal.create!(player_id: @player.id, position: 1, set_kind: "theme", set_key: "solo")
    Game::Market::PendingWantedRefresh.mark([ @player.id ])

    Game::Market::RefreshWantedJob.perform_now(@player.id)

    assert_equal [ [ @common.card_id, "goal" ] ], Game::Market::Wanted.where(player_id: @player.id).pluck(:card_id, :reason)
    assert_empty pending
  end

  test "the job skips a missing or a deleted player" do
    deleted = Accounts::Player.create!(deleted_at: 1.day.ago)

    assert_nothing_raised { [ 0, deleted.id ].each { Game::Market::RefreshWantedJob.perform_now(it) } }
    assert_empty Game::Market::Wanted.where(player_id: deleted.id)
  end
end

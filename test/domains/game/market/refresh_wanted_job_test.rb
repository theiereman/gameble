require "test_helper"
require_relative "../../../support/game_sets"
require_relative "../../../support/singleton_stub"

# An event that changes a player's wanted cards queues, once it commits, one rebuild of their rows per player it names.
class Game::Market::RefreshWantedJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GameSets
  include SingletonStub

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
      buyer_id: @other.id, goal_id: 1, sales: [ { buyer_id: @other.id } ], converted: [ { owner_id: @other.id } ] }
  end

  def named_by_every_event
    player = [ @player.id ]
    both = [ @player.id, @other.id ]
    {
      Game::PackOpened => player, Game::TradeAccepted => both, Game::Market::AuctionSold => both,
      Game::Market::OrderServed => [ @other.id, @player.id ], Game::Market::WantedChoicesApplied => both, Game::Market::CardListed => [ @other.id ],
      Game::Market::CardsEntrusted => player, Game::Market::ArchivePurchased => player, Game::GoalAdded => player,
      Game::GoalRemoved => player, Game::SlotBought => player, Game::CustomSetEdited => player, Game::CustomSetDeleted => player,
      Game::LibrarySetSynced => player, Game::Market::OrderPlaced => player, Game::Market::OrderCancelled => player,
      Game::Market::OrderExpired => player, Game::Market::OrderWithdrawn => player
    }
  end

  def refresh_raising_for(failing_player, error)
    real = Game::Market::RefreshWanted.method(:call)
    ->(player, **options) { player.id == failing_player.id ? raise(error) : real.call(player, **options) }
  end

  test "every heard event queues, once it commits, one refresh per player it names" do
    assert_equal named_by_every_event.keys.map(&:name).sort, Game::Market::Handlers::WantedRefresh::EVENTS.map(&:name).sort

    named_by_every_event.each do |event_class, players|
      assert_enqueued_jobs(players.size, only: Game::Market::RefreshWantedJob) { hear(event_class.new(data: every_key_data)) }
      players.each { assert_enqueued_with(job: Game::Market::RefreshWantedJob, args: [ it ]) }
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

  test "a refresh that raises leaves nothing pending, so the next event queues another" do
    hear(trade(@player, @other))
    clear_enqueued_jobs

    stub_singleton(Game::Market::RefreshWanted, :call, refresh_raising_for(@player, RuntimeError.new("boom"))) do
      assert_raises(RuntimeError) { Game::Market::RefreshWantedJob.perform_now(@player.id) }
    end

    assert_equal [ @other.id ], pending
    assert_enqueued_with(job: Game::Market::RefreshWantedJob, args: [ @player.id ]) { hear(trade(@player, @other)) }
  end

  test "a deadlocked refresh is tried again" do
    stub_singleton(Game::Market::RefreshWanted, :call, refresh_raising_for(@player, ActiveRecord::Deadlocked.new("deadlock"))) do
      assert_enqueued_with(job: Game::Market::RefreshWantedJob, args: [ @player.id ]) { Game::Market::RefreshWantedJob.perform_now(@player.id) }
    end
  end

  test "a player who left before their rebuild is skipped" do
    assert_nothing_raised { Game::Market::RefreshWantedJob.refresh(Accounts::Player.new) }
  end

  test "rebuilding every player reports one who raises with their id, rebuilds the others and returns the failed ids" do
    Game::Goal.create!(player_id: @other.id, position: 1, set_kind: "theme", set_key: "solo")

    failed = nil
    report = assert_error_reported(RuntimeError) do
      stub_singleton(Game::Market::RefreshWanted, :call, refresh_raising_for(@player, RuntimeError.new("boom"))) do
        failed = Game::Market::RebuildAllWantedJob.perform_now
      end
    end

    assert_equal @player.id, report.context[:player_id]
    assert_equal [ @player.id ], failed
    assert_equal [ [ @common.card_id, "goal" ] ], Game::Market::Wanted.where(player_id: @other.id).pluck(:card_id, :reason)
  end

  test "rebuilding every player returns no failed ids when none raised" do
    assert_empty Game::Market::RebuildAllWantedJob.perform_now
  end
end

require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_packs"

# Game::HealBanksJob (R3, epic 7 R6): a season published later fills the
# banks of the players who never had a pack, and heals those left short of
# ten (an emptied bank included), every new pack available at once; a full
# bank costs no operation.
class Game::HealBanksJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include CatalogSeeds
  include GamePacks

  setup { Game::DrawPool.reset! }

  test "publishing a season enqueues the job once the publication commits" do
    season = seed_card_seasons(distinct_scores(150))

    assert_enqueued_with(job: Game::HealBanksJob) do
      Catalog::PublishSeason.new.call(number: season.number).value!
    end
  end

  test "a failed publication enqueues nothing" do
    assert_no_enqueued_jobs { Catalog::PublishSeason.new.call(number: 99) }
  end

  test "players without any pack get ten; a short bank is topped up to ten; a banned player gets none" do
    create_pack(accounts_players(:moderator), opened_at: 1.minute.ago)
    season = seed_card_seasons(distinct_scores(150))

    perform_enqueued_jobs { Catalog::PublishSeason.new.call(number: season.number).value! }

    assert_equal 10, Game::Pack.where(player_id: accounts_players(:player).id, season_id: season.id).count
    assert_equal 10, Game::Pack.where(player_id: accounts_players(:administrator).id).count
    assert_equal 10, Game::Pack.bank(accounts_players(:moderator).id).count
    assert_equal 11, Game::Pack.where(player_id: accounts_players(:moderator).id).count
    assert_equal 0, Game::Pack.where(player_id: accounts_players(:banned).id).count
  end

  test "publishing a season: ten packs available now for a player with none, the missing ones available now for a short bank, a full bank untouched" do
    bankless, short, full = %i[player moderator administrator].map { accounts_players(it) }
    now = Time.current.change(usec: 0)
    travel_to(now - 1.hour) { Game::FillBank.new.call(player: full).value! }
    full_before = Game::Pack.bank(full.id).order(:id).pluck(:id, :available_at, :card_season_ids)
    create_pack(short, opened_at: now - 1.hour)
    kept = [ create_pack(short, available_at: now - 1.minute), create_pack(short, available_at: now + 5.minutes) ]
    season = seed_card_seasons(distinct_scores(150))

    travel_to(now) { perform_enqueued_jobs { Catalog::PublishSeason.new.call(number: season.number).value! } }

    bank = Game::Pack.bank(bankless.id)
    assert_equal [ now ] * 10, bank.pluck(:available_at)
    assert_equal [ season.id ], bank.distinct.pluck(:season_id)

    bank = Game::Pack.bank(short.id)
    assert_equal 10, bank.count
    assert_equal [ now ] * 8, bank.where.not(id: kept.map(&:id)).pluck(:available_at)
    assert_equal kept.map { [ it.id, it.available_at ] }, bank.where(id: kept.map(&:id)).order(:id).pluck(:id, :available_at)
    assert_equal [ { player_id: short.id, packs: 8 } ], game_events(short, Game::BankToppedUp).map(&:data)

    assert_equal full_before, Game::Pack.bank(full.id).order(:id).pluck(:id, :available_at, :card_season_ids)
    assert_empty game_events(full, Game::BankToppedUp)
  end

  test "a player whose fill raises is reported and the others still get their bank" do
    failing_id = accounts_players(:player).id
    fill = Game::FillBank.new
    Game::FillBank.define_singleton_method(:new) do
      Object.new.tap do |operation|
        operation.define_singleton_method(:call) do |player:|
          raise "the bank fill failed" if player.id == failing_id

          fill.call(player:)
        end
      end
    end
    begin
      assert_error_reported(RuntimeError) { Game::HealBanksJob.perform_now }
    ensure
      Game::FillBank.singleton_class.remove_method(:new)
    end

    assert_equal 0, Game::Pack.where(player_id: failing_id).count
    assert_equal 10, Game::Pack.where(player_id: accounts_players(:moderator).id).count
    assert_equal 10, Game::Pack.where(player_id: accounts_players(:administrator).id).count
  end

  # Records the players each of HealBank and FillBank is called for, while
  # the block runs; the operations still run.
  def recording_operations
    calls = Hash.new { |hash, operation| hash[operation] = [] }
    [ Game::HealBank, Game::FillBank ].each do |operation|
      original = operation.method(:new)
      operation.define_singleton_method(:new) do |*args, **options|
        real = original.call(*args, **options)
        Object.new.tap do |recorder|
          recorder.define_singleton_method(:call) do |player:|
            calls[operation] << player.id
            real.call(player:)
          end
        end
      end
    end
    yield
    calls
  ensure
    [ Game::HealBank, Game::FillBank ].each { |operation| operation.singleton_class.remove_method(:new) }
  end

  test "players whose bank is full cost no operation, and the job's queries do not grow with their number" do
    players = %i[player moderator administrator].map { accounts_players(it) }
    players.each { |player| Game::FillBank.new.call(player:).value! }
    # Bonus and opened packs beside a full bank change nothing.
    create_pack(players.first, kind: :bonus)
    create_pack(players.second, opened_at: 1.minute.ago)

    # The players of the batch, then their packs and banks, grouped.
    calls = recording_operations { assert_queries_count(2) { Game::HealBanksJob.perform_now } }
    assert_empty calls

    3.times do |index|
      player = Accounts::Player.create!(steam_id: "7656119796028710#{index}")
      Game::FillBank.new.call(player:).value!
    end
    calls = recording_operations { assert_queries_count(2) { Game::HealBanksJob.perform_now } }
    assert_empty calls
  end

  test "beside full banks, a short bank is healed and a player without a pack filled, once each" do
    full, short, bankless = %i[player moderator administrator].map { accounts_players(it) }
    [ full, short ].each { |player| Game::FillBank.new.call(player:).value! }
    Game::Pack.bank(short.id).order(:id).last.update_columns(opened_at: Time.current)
    # Unopened bonus and reward packs bring its unopened packs to eleven; its
    # bank of regular packs is still short.
    create_pack(short, kind: :bonus)
    create_pack(short, kind: :reward)

    calls = recording_operations { Game::HealBanksJob.perform_now }

    assert_equal({ Game::HealBank => [ short.id ], Game::FillBank => [ bankless.id ] }, calls)
    [ full, short, bankless ].each { |player| assert_equal 10, Game::Pack.bank(player.id).count }
  end

  test "a bank emptied while no season is published is refilled when one is published" do
    player = accounts_players(:player)
    create_pack(player)
    now = Time.current.change(usec: 0)

    # No season published at the opening: the pool is empty.
    current = Game::DrawPool.method(:current)
    Game::DrawPool.define_singleton_method(:current) { nil }
    begin
      travel_to(now) { Game::OpenPack.new.call(player:).value! }
    ensure
      Game::DrawPool.define_singleton_method(:current, current)
    end
    assert_equal 0, Game::Pack.bank(player.id).count

    season = seed_card_seasons(distinct_scores(150))
    travel_to(now) { perform_enqueued_jobs { Catalog::PublishSeason.new.call(number: season.number).value! } }

    bank = Game::Pack.bank(player.id)
    assert_equal 10, bank.count
    assert_equal [ season.id ], bank.distinct.pluck(:season_id)
    assert_equal [ now ] * 10, bank.order(:available_at).pluck(:available_at)
  end
end

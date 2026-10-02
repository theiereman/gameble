require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_packs"

# Game::HealBanksJob (R3): a season published later fills the banks of the
# players who never had a pack, and tops up those left short of ten (an
# emptied bank included).
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
    assert_equal (1..10).map { |step| now + (step * 10).minutes }, bank.order(:available_at).pluck(:available_at)
  end
end

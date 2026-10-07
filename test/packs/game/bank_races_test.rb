require "test_helper"
require_relative "../../support/game_packs"

# Bank operations of different stories raced against each other (epic 7 R6,
# AD-7, the epic 3 retrospective's B2): an opening (Game::OpenPack), a
# sign-up (Accounts::SignIn, whose handler fills the bank), a daily bonus
# (Game::CollectDailyBonus) and the healing of a season's publication
# (Game::HealBank, Game::FillBank, Game::HealBanksJob). The bank lock
# serialises them whatever their order, so each assertion holds for both
# orders. Every bank write reads the draw pool after reading the bank; the
# pool is slowed here, so without the lock both threads would read the bank
# before either writes. Each thread has its own connection, so the test
# commits for real and cleans up after itself.
class Game::BankRacesTest < ActiveSupport::TestCase
  include GamePacks

  self.use_transactional_tests = false

  # How long each read of the draw pool waits: the window in which an
  # unlocked operation would be overtaken.
  POOL_DELAY = 0.15

  setup do
    Game::DrawPool.reset!
    @player = accounts_players(:player)
    @created = []
    @current = Game::DrawPool.method(:current)
    current = @current
    Game::DrawPool.define_singleton_method(:current) do
      sleep POOL_DELAY
      current.call
    end
  end

  teardown do
    Game::DrawPool.define_singleton_method(:current, @current)
    players = Accounts::Player.pluck(:id)
    [ Game::DailyBonusClaim, Game::Holding, Game::FeedEntry, Game::WeeklyContribution, Game::Pack ].each do |model|
      model.where(player_id: players).delete_all
    end
    Game::PlayerState.where(player_id: @created).delete_all
    Game::FriendCode.where(player_id: @created).delete_all
    Accounts::Player.where(id: @created).delete_all
    streams = players.map { |id| Game::Operation.stream_name(id) } + @created.map { |id| "Accounts::Player$#{id}" }
    connection = ActiveRecord::Base.connection
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
  end

  # Runs the blocks at once, each on its own connection with a fresh copy of
  # the player, and returns their results in order.
  def race(*blocks)
    gate = Queue.new
    threads = blocks.map do |block|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          block.call(Accounts::Player.find(@player.id))
        end
      end
    end
    blocks.size.times { gate << :go }
    threads.map(&:value)
  end

  def heal = ->(player) { Game::HealBank.new.call(player:) }
  def fill = ->(player) { Game::FillBank.new.call(player:) }
  def open = ->(player) { Game::OpenPack.new.call(player:) }
  def bonus = ->(player) { Game::CollectDailyBonus.new.call(player:) }

  def bank(player = @player) = Game::Pack.bank(player.id)
  def topped_up(player = @player) = game_events(player, Game::BankToppedUp).map(&:data)
  def filled(player = @player) = game_events(player, Game::BankFilled).size

  # Unopened regular packs scheduled after `time` never share a time.
  def assert_unique_schedule(time)
    times = bank.where(available_at: time..).pluck(:available_at)
    assert_equal times.uniq, times, "scheduled packs should never share a time"
  end

  test "heal and open at once on a short bank: ten packs, one opened, seven healed" do
    3.times { |index| create_pack(@player, available_at: (index + 1).minutes.ago) }
    started = Time.current.change(usec: 0)

    results = race(heal, open)

    assert results.all?(&:success?)
    assert_equal 7, results.first.value!
    assert_equal 10, bank.count
    assert_equal 1, Game::Pack.where(player_id: @player.id).where.not(opened_at: nil).count
    assert_equal [ { player_id: @player.id, packs: 7 } ], topped_up
    assert_equal 7, bank.where(available_at: started..Time.current).count
    assert_unique_schedule(Time.current)
  end

  test "two heals at once on a short bank: ten packs, healed once" do
    create_pack(@player, available_at: 1.minute.ago)

    results = race(heal, heal)

    assert_equal [ 0, 9 ], results.map(&:value!).sort
    assert_equal 10, bank.count
    assert_equal [ { player_id: @player.id, packs: 9 } ], topped_up
  end

  test "the publication's fill and heal at once for a player with no pack: ten packs, filled once" do
    results = race(fill, heal)

    assert_equal [ 10, 0 ], results.map(&:value!)
    assert_equal 10, bank.count
    assert_equal 1, filled
    assert_empty topped_up
  end

  test "a sign-up while the publication's job runs: the new player has ten packs, filled once, never healed" do
    steam_id = "76561197960287999"

    results = race(
      ->(_player) { Accounts::SignIn.new.call(steam_id:) },
      ->(_player) { Game::HealBanksJob.perform_now }
    )

    signed_up = results.first.value!
    @created << signed_up.id
    assert_equal 10, bank(signed_up).count
    assert_equal 1, filled(signed_up)
    assert_empty topped_up(signed_up)
    %i[player moderator administrator].each { |name| assert_equal 10, bank(accounts_players(name)).count, name }
  end

  test "a daily bonus and the publication's fill at once for a player with no pack: ten packs, filled once, the bonus whole or refused" do
    collected, filling = race(bonus, fill)

    assert_predicate filling, :success?
    assert_equal 10, bank.count
    assert_equal 1, filled
    # The bonus first fills the bank itself, then adds its pack; after the
    # fill, the reserve holds ten available packs and refuses it, unclaimed.
    expected = collected.success? ? 1 : 0
    assert_equal :reserve_full, collected.failure unless collected.success?
    assert_equal expected, Game::Pack.where(player_id: @player.id).bonus.count
    assert_equal expected, Game::DailyBonusClaim.where(player_id: @player.id).count
  end

  test "a daily bonus and a heal at once on a short bank: ten packs and the bonus" do
    # Scheduled packs only: the reserve is never full, whichever runs first.
    3.times { |index| create_pack(@player, available_at: (index + 1).minutes.from_now) }

    results = race(bonus, heal)

    assert results.all?(&:success?)
    assert_equal 10, bank.count
    assert_equal 1, Game::Pack.where(player_id: @player.id).bonus.count
    assert_equal [ { player_id: @player.id, packs: 7 } ], topped_up
  end

  test "an opening and a daily bonus at once: both succeed, the bank stays at ten" do
    9.times { |index| create_pack(@player, available_at: (index + 1).minutes.ago) }
    create_pack(@player, available_at: 5.minutes.from_now)

    results = race(open, bonus)

    assert results.all?(&:success?)
    assert_predicate results.first.value!, :regular?
    assert_equal 10, bank.count
    assert_equal 1, Game::Pack.where(player_id: @player.id).bonus.unopened.count
    assert_empty topped_up
    assert_unique_schedule(Time.current)
  end
end

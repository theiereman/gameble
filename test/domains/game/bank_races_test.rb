require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/lock_races"

# Bank operations raced against each other: an opening (Game::OpenPack), a
# sign-up (Accounts::SignIn, whose handler fills the bank), a daily bonus
# (Game::CollectDailyBonus), the healing of a season's publication
# (Game::HealBank, Game::FillBank, Game::HealBanksJob), and two friends'
# operations beside a trade between them (Game::AcceptTrade), which takes
# both bank locks in ascending player order, then the holdings. The bank
# lock serialises them whatever their order, so each assertion holds for
# every order. Every bank write reads the draw pool after reading the bank;
# the pool is slowed here, so without the lock both threads would read the
# bank before either writes. Each thread has its own connection, so the
# test commits for real and cleans up after itself.
class Game::BankRacesTest < ActiveSupport::TestCase
  include GamePacks
  include LockRaces

  self.use_transactional_tests = false

  # How long each read of the draw pool waits: the window in which an
  # unlocked operation would be overtaken.
  POOL_DELAY = 0.15

  GOAL_WEEK = Date.new(2026, 10, 5)

  setup do
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
    trades = Game::Trade.where(proposer_id: players).or(Game::Trade.where(recipient_id: players))
    Game::FeedEntry.where(trade_id: trades.select(:id)).delete_all
    Game::TradeItem.where(trade_id: trades.select(:id)).delete_all
    trades.delete_all
    Game::Friendship.where(low_player_id: players).or(Game::Friendship.where(high_player_id: players)).delete_all
    # First discoveries made by this test's packs (the fixture ones have none).
    Game::FirstDiscovery.where(pack_id: Game::Pack.where(player_id: players).select(:id)).delete_all
    Game::WeeklyGoal.where(week_start: GOAL_WEEK).delete_all
    [ Game::GoalReward, Game::DailyBonusClaim, Game::Holding, Game::FeedEntry, Game::WeeklyContribution, Game::SetTier, Game::Pack ].each do |model|
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

  # Runs the blocks at once (LockRaces#together), each with a fresh copy of
  # the player, and returns their results in order.
  def race(*blocks)
    together(*blocks.map { |block| -> { block.call(Accounts::Player.find(@player.id)) } })
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
    assert_equal [ { player_id: @player.id, packs: 7, redrawn: 0 } ], topped_up
    assert_equal 7, bank.where(available_at: started..Time.current).count
    assert_unique_schedule(Time.current)
  end

  test "two heals at once on a short bank: ten packs, healed once" do
    create_pack(@player, available_at: 1.minute.ago)

    results = race(heal, heal)

    assert_equal [ 0, 9 ], results.map(&:value!).sort
    assert_equal 10, bank.count
    assert_equal [ { player_id: @player.id, packs: 9, redrawn: 0 } ], topped_up
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

  test "a daily bonus and the publication's fill at once for a player with no pack: ten packs, filled once, the bonus whole" do
    collected, filling = race(bonus, fill)

    assert_predicate filling, :success?
    assert_predicate collected, :success?
    assert_equal 10, bank.count
    assert_equal 1, filled
    assert_equal 1, Game::Pack.where(player_id: @player.id).bonus.count
    assert_equal 1, Game::DailyBonusClaim.where(player_id: @player.id).count
  end

  test "a daily bonus and a heal at once on a short bank: ten packs and the bonus" do
    # Scheduled packs only: the reserve is never full, whichever runs first.
    3.times { |index| create_pack(@player, available_at: (index + 1).minutes.from_now) }

    results = race(bonus, heal)

    assert results.all?(&:success?)
    assert_equal 10, bank.count
    assert_equal 1, Game::Pack.where(player_id: @player.id).bonus.count
    assert_equal [ { player_id: @player.id, packs: 7, redrawn: 0 } ], topped_up
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

  test "a daily bonus and an opening at once with ten standard capsules held: the opening costs one standard capsule, the bank refills to ten, the special reserve holds the bonus once" do
    10.times { |index| create_pack(@player, available_at: (index + 1).minutes.ago) }

    results = race(bonus, open)

    assert results.all?(&:success?)
    counts = Game::Reserve.counts(@player.id)
    assert_equal 9, counts.standard
    assert_equal 10, bank.count
    assert_equal 1, counts.special
    assert_equal 1, Game::DailyBonusClaim.where(player_id: @player.id).count
  end

  test "a daily bonus and a heal at once with ten standard capsules held: nothing healed, the standard reserve stays at ten, one bonus" do
    10.times { |index| create_pack(@player, available_at: (index + 1).minutes.ago) }

    collected, healing = race(bonus, heal)

    assert_predicate collected, :success?
    assert_equal 0, healing.value!
    counts = Game::Reserve.counts(@player.id)
    assert_equal 10, counts.standard
    assert_equal 1, counts.special
  end

  test "two claims of one goal reward at once: one reward capsule, the other claim refused" do
    Game::WeeklyGoal.create!(week_start: GOAL_WEEK, total: 200, target: 200)
    Game::WeeklyContribution.create!(player_id: @player.id, week_start: GOAL_WEEK, openings: 1)
    Game::GrantGoalReward.new.call(player: @player, week_start: GOAL_WEEK).value!

    results = race(*Array.new(2) { ->(player) { Game::ClaimGoalReward.new.call(player:, week_start: GOAL_WEEK) } })

    assert_equal 1, results.count(&:success?)
    assert_equal [ :reward_already_claimed ], results.reject(&:success?).map(&:failure)
    assert_equal 1, Game::Pack.where(player_id: @player.id).reward.count
    assert_equal 1, Game::GoalReward.where(player_id: @player.id).where.not(pack_id: nil).count
  end

  test "an opening, a daily bonus and a heal at once on a short bank: both succeed, ten packs and the bonus, each pack spent once" do
    4.times { |index| create_pack(@player, available_at: (index + 1).minutes.ago) }
    2.times { |index| create_pack(@player, available_at: (index + 1).minutes.from_now) }
    open_unpublished(@player, 3)

    opening, collected, healing = race(open, bonus, heal)

    # One available pack and the healed ones at most: the reserve is never
    # full, and the opening takes the oldest pack, whichever runs first.
    assert_predicate opening, :success?
    assert_predicate opening.value!, :regular?
    assert_predicate collected, :success?
    assert_equal 7, healing.value!
    assert_equal 10, bank.count
    assert_equal 1, Game::Pack.where(player_id: @player.id).bonus.unopened.count
    assert_equal [ { player_id: @player.id, packs: 7, redrawn: 0 } ], topped_up
    assert_spent_once(@player)
  end

  test "two openings and a heal at once on the last available pack: each pack opened once, ten packs" do
    3.times { |index| create_pack(@player, available_at: (index + 1).minutes.ago) }
    open_unpublished(@player, 2)

    *openings, healing = race(open, open, heal)

    # Before the heal commits, the second opening finds only the last pack's
    # scheduled replacement.
    opened = openings.select(&:success?).map(&:value!)
    assert_not_empty opened
    assert_equal opened.map(&:id).uniq, opened.map(&:id)
    openings.reject(&:success?).each { |refused| assert_equal :no_pack_available, refused.failure }
    assert_equal 9, healing.value!
    assert_equal 10, bank.count
    assert_equal 2 + opened.size, Game::Pack.where(player_id: @player.id).where.not(opened_at: nil).count
    assert_spent_once(@player)
  end

  test "two first sign-ins with one Steam id at once: one player, ten packs, filled and registered once" do
    steam_id = "76561197960287998"

    results = race(*Array.new(2) { ->(_player) { Accounts::SignIn.new.call(steam_id:) } })
    @created.concat(Accounts::Player.where(steam_id:).ids)

    assert results.all?(&:success?), results.inspect
    signed_up = results.first.value!
    assert_equal [ signed_up.id ], results.map { |result| result.value!.id }.uniq
    assert_equal [ signed_up.id ], Accounts::Player.where(steam_id:).pluck(:id)
    assert_equal 10, bank(signed_up).count
    assert_equal 1, filled(signed_up)
    assert_equal 1, Rails.configuration.event_store.read.stream("Accounts::Player$#{signed_up.id}").of_type([ Accounts::PlayerRegistered ]).count
  end

  def copies(*players) = Game::Holding.uncached { Game::Holding.where(player_id: players.map(&:id)).sum(:quantity) }

  test "two friends opening, collecting, healing and trading at once: every copy accounted for" do
    alice = @player
    bob = Accounts::Player.find(accounts_players(:moderator).id)
    portal = catalog_card_seasons(:portal_one).id
    rare = catalog_card_seasons(:rare_card_one).id
    low, high = [ alice.id, bob.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    Game::Holding.create!(player_id: alice.id, card_season_id: portal, quantity: 2)
    Game::Holding.create!(player_id: bob.id, card_season_id: rare, quantity: 1)
    9.times { |index| create_pack(alice, available_at: (index + 1).minutes.ago) }
    create_pack(alice, available_at: 5.minutes.from_now)
    3.times { |index| create_pack(bob, available_at: (index + 1).minutes.ago) }
    trade = Game::ProposeTrade.new.call(player: alice, recipient: bob, offer: { portal => 1 }, request: { rare => 1 }).value!
    before = copies(alice, bob)

    results = race(
      ->(player) { [ open.call(player), bonus.call(player) ] },
      ->(_player) { [ open.call(Accounts::Player.find(bob.id)), heal.call(Accounts::Player.find(bob.id)) ] },
      ->(_player) { [ Game::AcceptTrade.new.call(player: Accounts::Player.find(bob.id), trade_id: trade.id, revision: trade.revision) ] }
    ).flatten

    assert results.all?(&:success?), results.inspect
    opened = Game::Pack.where(player_id: [ alice.id, bob.id ]).where.not(opened_at: nil)
    assert_equal({ alice.id => 1, bob.id => 1 }, opened.group(:player_id).count)
    assert_equal before + (Game::Pack::SIZE * 2), copies(alice, bob)
    assert_equal "accepted", trade.reload.status
    held = Game::Holding.where(player_id: [ alice.id, bob.id ]).pluck(:player_id, :card_season_id, :quantity, :reserved)
    assert_equal [ [ alice.id, portal, 6, 0 ], [ alice.id, rare, 1, 0 ], [ bob.id, portal, 6, 0 ], [ bob.id, rare, 0, 0 ] ].sort, held.sort
    assert_equal 10, bank(alice).count
    assert_equal 1, Game::Pack.where(player_id: alice.id).bonus.unopened.count
    assert_equal 10, bank(bob).count
  end
end

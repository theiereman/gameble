require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/rake_tasks"
require_relative "../../support/holdings"

class Game::AchievementsTest < ActiveSupport::TestCase
  include Holdings
  include ActionCable::TestHelper
  include ActiveJob::TestHelper
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
    @common, @uncommon, @rare, @epic, @legendary = fixture_tier_ids
  end

  def grant(key, player: @player, retroactive: false) = Game::GrantAchievement.new.call(player:, achievement: key, retroactive:)
  def unlocked(player = @player) = Game::AchievementUnlock.where(player_id: player.id).order(:id).pluck(:achievement)
  def unlock_events(player = @player) = game_events(player, Game::AchievementUnlocked)
  def progress(player = @player) = Game::AchievementProgress.call(player)

  def opened_packs(count, player: @player, kind: :regular)
    count.times { create_pack(player, kind:, opened_at: Time.current) }
  end

  # Completes `count` franchise sets of the season, each under a key of its own unless `keys` names them.
  def complete_sets(count, player: @player, season: catalog_seasons(:one), keys: nil)
    keys ||= Array.new(count) { "done-#{player.id}-#{Catalog::Set.count + it}" }
    set_ids = Catalog::Set.insert_all!(keys.map { |key| { season_id: season.id, kind: "franchise", key:, params: { "franchise" => key } } },
      returning: :id).rows.flatten
    Game::SetTier.insert_all!(set_ids.map { |set_id| { player_id: player.id, set_id:, tier: "complete", reached_by: "trade", reached_at: Time.current } })
  end

  def second_season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)

  def open_with_jobs(cards, player: @player)
    create_pack(player, cards:)
    perform_enqueued_jobs { Game::OpenPack.new.call(player:).value! }
  end

  def befriend(one, two)
    low, high = [ one.id, two.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def propose_trade(proposer: @player, recipient: @other)
    { proposer => @common, recipient => @uncommon }.each do |player, card_season_id|
      hold(player, card_season_id) unless Game::Holding.exists?(player_id: player.id, card_season_id:)
    end
    Game::ProposeTrade.new.call(player: proposer, recipient:, offer: { @common => 1 }, request: { @uncommon => 1 }).value!
  end

  def accept_trade(trade, player: @other)
    Game::AcceptTrade.new.call(player:, trade_id: trade.id, revision: Game::Trade.find(trade.id).revision).value!
  end

  test "the catalogue holds ten achievements, in order, each a metric and a threshold" do
    expected = [
      [ :first_booster, :packs_opened, 1 ], [ :first_epic, :epics_obtained, 1 ], [ :first_legendary, :legendaries_obtained, 1 ],
      [ :first_complete_set, :sets_completed, 1 ], [ :first_trade, :trades_accepted, 1 ], [ :boosters_10, :packs_opened, 10 ],
      [ :boosters_100, :packs_opened, 100 ], [ :boosters_500, :packs_opened, 500 ], [ :three_complete_sets, :sets_completed, 3 ],
      [ :first_repost, :reposts, 1 ]
    ]

    assert_equal expected, Game::Achievements::CATALOGUE.map { [ it.key, it.metric, it.threshold ] }
    assert Game::Achievements::CATALOGUE.map(&:metric).all? { Game::AchievementProgress::METRICS.include?(it) }
    assert_equal :boosters_10, Game::Achievements.find("boosters_10").key
    assert_nil Game::Achievements.find("boosters_11")
  end

  test "every achievement has a name in both locales" do
    Game::Achievements::CATALOGUE.each do |achievement|
      %i[en fr].each { |locale| assert I18n.exists?("achievements.names.#{achievement.key}", locale), "#{achievement.key} in #{locale}" }
    end
  end

  test "progress is zero for a visitor and for a player who has done nothing" do
    zeros = Game::AchievementProgress::METRICS.index_with(0)

    assert_equal zeros, progress(nil)
    assert_equal zeros, progress
  end

  test "packs opened count every kind of opened pack, never an unopened one or another player's" do
    opened_packs(2)
    opened_packs(1, kind: :bonus)
    create_pack(@player)
    opened_packs(3, player: @other)

    assert_equal 3, progress[:packs_opened]
  end

  test "Épiques and Légendaires obtained count the holding rows of exactly that tier, copies traded away included" do
    hold(@player, @epic, 0)
    hold(@player, @legendary, 2)
    hold(@player, @rare, 4)
    hold(@other, @epic, 1)

    assert_equal [ 1, 1 ], progress.values_at(:epics_obtained, :legendaries_obtained)
  end

  test "an Épique held in two seasons is one game obtained" do
    portal_two = Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: second_season.id, prestige_score: 0.9,
      rating: 95, rarity: 4, number: 1 } ], returning: :id).rows.flatten.sole
    hold(@player, @epic)
    hold(@player, portal_two)

    assert_equal 1, progress[:epics_obtained]
  end

  test "sets completed count the player's completions" do
    complete_sets(2)
    complete_sets(1, player: @other)

    assert_equal 2, progress[:sets_completed]
  end

  test "sets completed count a set's kind and key once, whatever the seasons it was completed in; a tier below complete counts nothing" do
    complete_sets(1, keys: [ "dark-souls" ])
    complete_sets(1, season: second_season, keys: [ "dark-souls" ])
    Game::SetTier.insert_all!([ { player_id: @player.id, set_id: catalog_sets(:valve_one).id, tier: "gold", reached_by: "trade", reached_at: Time.current } ])

    assert_equal 1, progress[:sets_completed]
  end

  test "a set completed again in a later season grants the first complete set once and never advances three complete sets" do
    complete_sets(1, keys: [ "dark-souls" ])
    complete_sets(1, season: second_season, keys: [ "dark-souls", "portal" ])

    Game::GrantAchievementsJob.perform_now(@player.id)

    assert_equal 2, progress[:sets_completed]
    assert_includes unlocked, "first_complete_set"
    assert_not_includes unlocked, "three_complete_sets"
  end

  test "trades accepted count the accepted trades on either side, never an open one" do
    befriend(@player, @other)
    accept_trade(propose_trade)
    propose_trade(proposer: @other, recipient: @player)

    assert_equal [ 1, 1 ], [ progress[:trades_accepted], progress(@other)[:trades_accepted] ]
  end

  test "reposts count the player's repost entries" do
    hold(@player, @common)
    hold(@player, @epic)
    [ @common, @epic ].each { Game::RepostCard.new.call(player: @player, card_season_id: it).value! }

    assert_equal 2, progress[:reposts]
  end

  test "a met achievement is unlocked once, with its event on the player's stream" do
    opened_packs(1)
    now = Time.utc(2026, 10, 12, 9)

    result = travel_to(now) { grant(:first_booster) }

    assert_equal :first_booster, result.value!.key
    unlock = Game::AchievementUnlock.sole
    assert_equal [ @player.id, "first_booster", now ], [ unlock.player_id, unlock.achievement, unlock.unlocked_at ]
    assert_equal [ { player_id: @player.id, achievement: "first_booster" } ], unlock_events.map(&:data)
  end

  test "an achievement already unlocked is refused and adds no row and no event" do
    opened_packs(1)
    grant(:first_booster).value!

    assert_no_difference -> { Game::AchievementUnlock.count + Rails.configuration.event_store.read.count } do
      assert_equal :already_unlocked, grant(:first_booster).failure
      assert_equal :already_unlocked, grant("first_booster", retroactive: true).failure
    end
  end

  test "an achievement not met, or not in the catalogue, writes nothing" do
    opened_packs(9)

    assert_no_difference -> { Game::AchievementUnlock.count + Rails.configuration.event_store.read.count } do
      assert_equal :not_reached, grant(:boosters_10).failure
      assert_equal :not_reached, grant(:first_trade).failure
      assert_equal :unknown_achievement, grant(:boosters_9).failure
      assert_equal :unknown_achievement, grant(nil).failure
    end
  end

  test "a visitor, a banned or a deleted player is refused" do
    banned = accounts_players(:banned)
    opened_packs(1, player: banned)
    opened_packs(1)

    assert_no_difference -> { Game::AchievementUnlock.count } do
      assert_equal :player_required, grant(:first_booster, player: nil).failure
      assert_equal :player_required, grant(:first_booster, player: banned).failure
      @player.update!(deleted_at: Time.current, steam_id: nil)
      assert_equal :player_required, grant(:first_booster).failure
    end
  end

  test "a retroactive unlock says so in its event" do
    opened_packs(1)

    grant(:first_booster, retroactive: true).value!

    assert_equal [ { player_id: @player.id, achievement: "first_booster", retroactive: true } ], unlock_events.map(&:data)
  end

  test "a first opening unlocks the first booster once, toasted to the player's stream only" do
    open_with_jobs([ @common ] * 5)

    assert_equal [ "first_booster" ], unlocked
    assert_equal [ { player_id: @player.id, achievement: "first_booster" } ], unlock_events.map(&:data)
    toasts = broadcasts(PlayerStream.name(@player, :fr)).map { ActiveSupport::JSON.decode(it) }
    assert_equal 1, toasts.size
    assert_match "Succès débloqué", toasts.sole
    assert_match "Première capsule", toasts.sole
    assert_match "Achievement unlocked", ActiveSupport::JSON.decode(broadcasts(PlayerStream.name(@player, :en)).sole)
    assert_no_broadcasts PlayerStream.name(@other, :fr)
  end

  test "an Épique pulled unlocks the first Épique; a Légendaire alone unlocks the first Légendaire only" do
    open_with_jobs([ @legendary ] + [ @common ] * 4)

    assert_equal %w[first_booster first_legendary], unlocked

    open_with_jobs([ @epic ] + [ @common ] * 4)

    assert_includes unlocked, "first_epic"
  end

  test "the tenth opening unlocks ten boosters once, and the eleventh nothing more" do
    opened_packs(9)

    open_with_jobs([ @common ] * 5)
    assert_equal %w[first_booster boosters_10], unlocked

    assert_no_difference -> { unlock_events.size } do
      open_with_jobs([ @common ] * 5)
    end
    assert_equal %w[first_booster boosters_10], unlocked
  end

  test "a first set completed unlocks the first complete set, the third three complete sets" do
    open_with_jobs([ @epic ] + [ @common ] * 4, player: @other)
    assert_includes unlocked(@other), "first_complete_set"
    assert_not_includes unlocked(@other), "three_complete_sets"

    complete_sets(2)
    open_with_jobs([ @epic ] + [ @common ] * 4)

    assert_equal 1, game_events(@player, Game::SetCompleted).size
    assert_includes unlocked, "three_complete_sets"
  end

  test "an accepted trade unlocks the first trade for both players" do
    befriend(@player, @other)
    trade = propose_trade

    perform_enqueued_jobs { accept_trade(trade) }

    assert_includes unlocked(@player), "first_trade"
    assert_includes unlocked(@other), "first_trade"
  end

  test "a first repost unlocks the first repost" do
    hold(@player, @common)

    perform_enqueued_jobs { Game::RepostCard.new.call(player: @player, card_season_id: @common).value! }

    assert_equal [ "first_repost" ], unlocked
  end

  test "every trigger enqueues the grant for its players" do
    data = { player_id: @player.id, proposer_id: @player.id, recipient_id: @other.id }

    assert_enqueued_jobs 6, only: Game::GrantAchievementsJob do
      Game::Handlers::Achievements::EVENTS.each_key { Game::Handlers::Achievements.call(it.new(data:)) }
    end
  end

  test "the grant job serves a met achievement once and skips a banned, a deleted or a missing player" do
    opened_packs(1)
    banned = accounts_players(:banned)
    opened_packs(1, player: banned)

    2.times { Game::GrantAchievementsJob.perform_now(@player.id) }
    Game::GrantAchievementsJob.perform_now(banned.id)
    Game::GrantAchievementsJob.perform_now(0)

    assert_equal [ "first_booster" ], unlocked
    assert_equal 1, unlock_events.size
    assert_empty unlocked(banned)
  end

  test "the account's deletion deletes its unlocks" do
    opened_packs(1)
    opened_packs(1, player: @other)
    [ @player, @other ].each { Game::GrantAchievementsJob.perform_now(it.id) }

    Accounts::DeletePlayer.new.call(player: @player).value!

    assert_empty unlocked
    assert_equal [ "first_booster" ], unlocked(@other)
  end
end

class Game::BackfillAchievementsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GamePacks
  include RakeTasks

  setup do
    rake_task("game:backfill_achievements")
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
    @banned = accounts_players(:banned)
    [ @player, @other, @banned ].each { create_pack(it, opened_at: Time.current) }
    create_pack(@player, cards: [ fixture_tier_ids.last ] * 5, opened_at: Time.current)
    Game::Holding.create!(player_id: @player.id, card_season_id: fixture_tier_ids.last, quantity: 5)
  end

  def unlocked = Game::AchievementUnlock.pluck(:player_id, :achievement).sort

  def expected = [ [ @player.id, "first_booster" ], [ @player.id, "first_legendary" ], [ @other.id, "first_booster" ] ].sort

  def run_task = rake_task("game:backfill_achievements").execute

  test "players in good standing get what they met, silently, once however often it runs" do
    assert_no_enqueued_jobs(only: PlayerStreamJob) do
      2.times { Game::BackfillAchievementsJob.perform_now }
    end

    assert_equal expected, unlocked
    events = Rails.configuration.event_store.read.of_type(Game::AchievementUnlocked).to_a
    assert_equal 3, events.size
    assert events.all? { it.data[:retroactive] }
  end

  test "a player whose grant raises is reported, and the others are still served" do
    grant = Game::GrantAchievementsJob.method(:grant)
    failing_id = @player.id
    Game::GrantAchievementsJob.define_singleton_method(:grant) do |player, **options|
      raise "the grant failed" if player.id == failing_id

      grant.call(player, **options)
    end

    assert_error_reported(RuntimeError) { Game::BackfillAchievementsJob.perform_now }

    assert_equal [ [ @other.id, "first_booster" ] ], unlocked
  ensure
    Game::GrantAchievementsJob.define_singleton_method(:grant, grant)
  end

  test "the rake task runs the backfill and says so" do
    output, = capture_io { 2.times { run_task } }

    assert_equal expected, unlocked
    assert_match "game:backfill_achievements", output
  end
end

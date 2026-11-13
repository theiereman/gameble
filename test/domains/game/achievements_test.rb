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
  def progress(player = @player, metrics = Game::AchievementProgress::METRICS) = Game::AchievementProgress.call(player, metrics)

  def commons(kind = :regular) = Array.new(kind.to_s == "bonus" ? Game::Pack::BONUS_SIZE : Game::Pack::SIZE, @common)

  def opened_packs(count, player: @player, kind: :regular, cards: commons(kind))
    count.times { create_pack(player, kind:, cards:, opened_at: Time.current) }
  end

  def two_rare_or_better(player = @player) = progress(player, [ :two_rare_or_better_capsules ]).fetch(:two_rare_or_better_capsules)

  def toasts(player, locale) = broadcasts(PlayerStream.name(player, locale)).map { ActiveSupport::JSON.decode(it) }

  def progress_reads
    asked = []
    original = Game::AchievementProgress.method(:call)
    Game::AchievementProgress.define_singleton_method(:call) do |player, metrics|
      asked << metrics
      original.call(player, metrics)
    end
    yield
    asked
  ensure
    Game::AchievementProgress.define_singleton_method(:call, original)
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

  test "the catalogue opens with twenty-three achievements, in order, each a metric and a threshold" do
    expected = [
      [ :first_booster, :packs_opened, 1 ], [ :first_epic, :epics_obtained, 1 ], [ :first_legendary, :legendaries_obtained, 1 ],
      [ :first_complete_set, :sets_completed, 1 ], [ :first_trade, :trades_accepted, 1 ], [ :boosters_10, :packs_opened, 10 ],
      [ :boosters_100, :packs_opened, 100 ], [ :boosters_500, :packs_opened, 500 ], [ :three_complete_sets, :sets_completed, 3 ],
      [ :first_repost, :reposts, 1 ], [ :statistical_non_compliance, :two_rare_or_better_capsules, 1 ],
      [ :packaging_irregularity, :repeated_game_capsules, 1 ], [ :excellence_in_mediocrity, :all_common_capsules, 1 ],
      [ :historical_asset_management, :old_and_new_game_capsules, 1 ], [ :luck_is_a_marketing_concept, :capsules_without_rare_streak, 10 ],
      [ :leave_request_denied, :daily_bonus_streak, 7 ], [ :streamlined_opening_procedure, :reveal_all_streak, 10 ],
      [ :diligence_beyond_the_call_of_duty, :reveal_one_by_one_streak, 10 ], [ :diversified_portfolio, :most_copies_of_a_game, 5 ],
      [ :market_concentration, :most_games_of_a_studio, 10 ], [ :first_claim_all_rights_reserved, :first_discoveries, 1 ],
      [ :a_discovery_of_ours, :pioneered_reposts, 1 ], [ :a_strictly_professional_relationship, :most_trades_with_a_partner, 3 ]
    ]

    assert_equal expected, Game::Achievements::CATALOGUE.first(expected.size).map { [ it.key, it.metric, it.threshold ] }
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

  test "progress reads only the metrics asked for, and nothing at all for none" do
    opened_packs(2)

    assert_equal({ packs_opened: 2 }, progress(@player, [ :packs_opened ]))
    assert_equal({ reposts: 0 }, progress(nil, [ :reposts ]))
    assert_queries_count(0) { assert_equal({}, progress(@player, [])) }
  end

  test "a standard capsule with two Rare-or-better cards counts, copies included" do
    opened_packs(1, cards: [ @rare, @epic ] + [ @common ] * 3)
    assert_equal 1, two_rare_or_better

    opened_packs(1, cards: [ @rare, @rare ] + [ @common ] * 3)
    assert_equal 2, two_rare_or_better
  end

  test "a single Rare-or-better card, a bonus or reward capsule, an unopened capsule or another player's never counts" do
    opened_packs(1, cards: [ @legendary, @uncommon ] + [ @common ] * 3)
    opened_packs(1, kind: :bonus, cards: [ @rare, @epic, @common ])
    opened_packs(1, kind: :reward, cards: [ @epic, @legendary ])
    create_pack(@player, cards: [ @rare, @epic ] + [ @common ] * 3)
    opened_packs(1, player: @other, cards: [ @rare, @epic ] + [ @common ] * 3)

    assert_equal 0, two_rare_or_better
    assert_equal 1, two_rare_or_better(@other)
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

  test "Statistical Non-Compliance is granted once for two Rare-or-better cards in one capsule, and refused on a near miss" do
    opened_packs(1, cards: [ @legendary ] + [ @uncommon ] * 4)
    assert_no_difference -> { Game::AchievementUnlock.count + Rails.configuration.event_store.read.count } do
      assert_equal :not_reached, grant(:statistical_non_compliance).failure
    end

    opened_packs(1, cards: [ @rare, @epic ] + [ @common ] * 3)

    assert_equal :statistical_non_compliance, grant(:statistical_non_compliance).value!.key
    assert_equal :already_unlocked, grant(:statistical_non_compliance).failure
    assert_equal [ "statistical_non_compliance" ], unlocked
  end

  def card_id_of(card_season_id) = Catalog::CardSeason.find(card_season_id).card_id

  def capsule_metric(metric, player = @player) = progress(player, [ metric ]).fetch(metric)

  def open_regular(*cards_per_pack, player: @player, kind: :regular)
    cards_per_pack.each_with_index do |cards, index|
      create_pack(player, kind:, cards: cards || commons(kind), opened_at: Time.utc(2026, 1, 1) + index.minutes)
    end
  end

  def claim_days(days, player: @player)
    days.each do |day|
      pack = create_pack(player, kind: :bonus)
      Game::DailyBonusClaim.create!(player_id: player.id, day:, pack_id: pack.id)
    end
  end

  def days_from(first, count) = Array.new(count) { Date.new(2026, 3, 1) + first + it }

  def luck_streak(player = @player) = capsule_metric(:capsules_without_rare_streak, player)

  def bonus_streak(player = @player) = capsule_metric(:daily_bonus_streak, player)

  def release!(card_season_id, date) = Catalog::Card.where(id: card_id_of(card_season_id)).update_all(release_date: date)

  test "a capsule of any kind holding the same game twice counts, a near miss never" do
    opened_packs(1, cards: [ @common, @uncommon, @rare, @epic, @legendary ])
    opened_packs(1, kind: :bonus, cards: [ @common, @common, @rare ])
    opened_packs(1, kind: :reward, cards: [ @uncommon, @uncommon ])
    assert_equal 2, capsule_metric(:repeated_game_capsules)

    create_pack(@player, cards: [ @rare, @rare, @common, @uncommon, @epic ])
    opened_packs(1, player: @other, cards: [ @common, @uncommon, @rare, @epic, @legendary ])
    assert_equal 2, capsule_metric(:repeated_game_capsules)
    assert_equal 0, capsule_metric(:repeated_game_capsules, @other)
  end

  test "Packaging Irregularity is granted on a capsule with a repeated game and refused on a capsule of five different games" do
    opened_packs(1, cards: [ @common, @uncommon, @rare, @epic, @legendary ])
    assert_equal :not_reached, grant(:packaging_irregularity).failure

    opened_packs(1, cards: [ @legendary, @legendary, @common, @uncommon, @rare ])
    assert_equal :packaging_irregularity, grant(:packaging_irregularity).value!.key
  end

  test "a standard capsule of five Common cards counts, a near miss never" do
    opened_packs(1, cards: [ @common ] * 4 + [ @uncommon ])
    opened_packs(1, kind: :bonus, cards: [ @common ] * 3)
    opened_packs(1, kind: :reward, cards: [ @common ] * 5)
    create_pack(@player, cards: [ @common ] * 5)
    opened_packs(1, player: @other, cards: [ @common ] * 4 + [ @rare ])
    assert_equal 0, capsule_metric(:all_common_capsules)

    opened_packs(2)
    assert_equal 2, capsule_metric(:all_common_capsules)
    assert_equal 0, capsule_metric(:all_common_capsules, @other)
  end

  test "Excellence in Mediocrity is granted on a standard capsule of Common cards and refused on four" do
    opened_packs(1, cards: [ @common ] * 4 + [ @uncommon ])
    assert_equal :not_reached, grant(:excellence_in_mediocrity).failure

    opened_packs(1)
    assert_equal :excellence_in_mediocrity, grant(:excellence_in_mediocrity).value!.key
  end

  test "a capsule with a game released before 2000 and one from 2025 on counts, a near miss never" do
    release!(@rare, Date.new(2025, 1, 1))
    release!(@epic, Date.new(1999, 12, 31))
    opened_packs(1, cards: [ @legendary, @common, @uncommon, @uncommon, @common ])
    opened_packs(1, cards: [ @rare, @common, @uncommon, @uncommon, @common ])
    opened_packs(1, cards: [ @epic, @common, @uncommon, @uncommon, @common ])
    assert_equal 0, capsule_metric(:old_and_new_game_capsules)

    opened_packs(1, kind: :bonus, cards: [ @epic, @rare, @uncommon ])
    opened_packs(1, cards: [ @legendary, @rare, @uncommon, @uncommon, @common ])
    create_pack(@player, cards: [ @epic, @rare, @uncommon, @uncommon, @common ])
    opened_packs(1, player: @other, cards: [ @uncommon, @common, @common, @uncommon, @uncommon ])
    assert_equal 2, capsule_metric(:old_and_new_game_capsules)
    assert_equal 0, capsule_metric(:old_and_new_game_capsules, @other)
  end

  test "Historical Asset Management is granted on an old and a new game in one capsule and refused when they come from two" do
    release!(@rare, Date.new(2026, 3, 1))
    opened_packs(1, cards: [ @legendary, @common, @uncommon, @uncommon, @common ])
    opened_packs(1, cards: [ @rare, @common, @uncommon, @uncommon, @common ])
    assert_equal :not_reached, grant(:historical_asset_management).failure

    opened_packs(1, cards: [ @legendary, @rare, @uncommon, @uncommon, @common ])
    assert_equal :historical_asset_management, grant(:historical_asset_management).value!.key
  end

  test "the capsule streak is the longest run of opened standard capsules with no Rare or better card, in opening order" do
    open_regular(nil, nil, nil, [ @rare ] + [ @common ] * 4, nil, nil, [ @common ] * 4 + [ @uncommon ], nil, nil, [ @epic ] + [ @common ] * 4, nil)
    assert_equal 5, luck_streak

    open_regular(*Array.new(2) { [ @legendary ] + [ @common ] * 4 }, player: @other)
    assert_equal 0, luck_streak(@other)
  end

  test "the capsule streak ignores bonus, reward, unopened capsules and other players' capsules" do
    open_regular(nil, nil, nil, [ @rare ] + [ @common ] * 4, nil)
    open_regular(*Array.new(5) { nil }, kind: :bonus, player: @other)
    open_regular(*Array.new(5) { [ @common ] * 3 }, kind: :bonus)
    open_regular(*Array.new(5) { nil }, kind: :reward)
    create_pack(@player, cards: commons)
    assert_equal 3, luck_streak
    assert_equal 0, luck_streak(@other)
  end

  test "the capsule streak follows opened_at rather than creation order" do
    later = Time.utc(2026, 6, 1)
    create_pack(@player, cards: [ @rare ] + [ @common ] * 4, opened_at: later)
    5.times { create_pack(@player, cards: commons, opened_at: later - 1.day - it.minutes) }
    5.times { create_pack(@player, cards: commons, opened_at: later + 1.day + it.minutes) }
    assert_equal 5, luck_streak
  end

  test "Luck Is a Marketing Concept is granted at exactly ten capsules without a Rare and refused at nine" do
    open_regular(*Array.new(9) { nil })
    assert_equal 9, luck_streak
    assert_equal :not_reached, grant(:luck_is_a_marketing_concept).failure

    open_regular(*Array.new(10) { nil }, player: @other)
    assert_equal :luck_is_a_marketing_concept, grant(:luck_is_a_marketing_concept, player: @other).value!.key
  end

  test "a Rare capsule breaks the run, which restarts the count" do
    open_regular(*Array.new(9) { nil }, [ @rare ] + [ @common ] * 4, *Array.new(9) { nil })
    assert_equal 9, luck_streak
    assert_equal :not_reached, grant(:luck_is_a_marketing_concept).failure

    create_pack(@player, cards: commons, opened_at: Time.utc(2026, 2, 1))
    assert_equal :luck_is_a_marketing_concept, grant(:luck_is_a_marketing_concept).value!.key
  end

  test "the daily bonus streak is the longest run of consecutive UTC days, a gap restarting it" do
    claim_days(days_from(0, 3) + days_from(4, 6) + days_from(11, 2))
    assert_equal 6, bonus_streak

    claim_days(days_from(0, 7), player: @other)
    assert_equal 7, bonus_streak(@other)
    assert_equal 0, bonus_streak(accounts_players(:banned))
  end

  test "the daily bonus streak counts days across a month and a year end, and one claim a day" do
    claim_days([ Date.new(2025, 12, 30), Date.new(2025, 12, 31), Date.new(2026, 1, 1), Date.new(2026, 1, 2) ])
    assert_equal 4, bonus_streak
  end

  test "Leave Request Denied is granted at exactly seven days in a row and refused at six" do
    claim_days(days_from(0, 6))
    assert_equal :not_reached, grant(:leave_request_denied).failure

    claim_days(days_from(7, 1))
    assert_equal :not_reached, grant(:leave_request_denied).failure

    claim_days(days_from(6, 1))
    assert_equal :leave_request_denied, grant(:leave_request_denied).value!.key
  end

  test "collecting the daily bonus grants Leave Request Denied on the seventh day, toasted in each locale" do
    today = Game::DailyBonusClaim.day_of(Time.current)
    claim_days((1..6).map { today - it })
    assert_empty unlocked

    perform_enqueued_jobs { Game::CollectDailyBonus.new.call(player: @player).value! }

    assert_includes unlocked, "leave_request_denied"
    assert_equal 1, toasts(@player, :fr).count { it.include?("Demande de congé refusée") }
    assert_equal 1, toasts(@player, :en).count { it.include?("Leave Request Denied") }
  end

  def published_edition(season, card_id, number)
    Catalog::CardSeason.insert_all!([ { card_id:, season_id: season.id, prestige_score: 0.5, rating: 80.0,
      rarity: Catalog::Rarity::TIERS.invert.fetch(:common), number: } ], returning: :id).rows.flatten.sole
  end

  def hold_edition(card_id, quantity, reserved: 0)
    season = Catalog::Season.create!(status: :published, number: Catalog::Season.next_number, published_at: Time.current)
    hold(@player, published_edition(season, card_id, 1), quantity, reserved:)
  end

  def studio_games(count, developer: [ "Acme Studios" ], player: @player)
    season = Catalog::Season.create!(status: :published, number: Catalog::Season.next_number, published_at: Time.current)
    Array.new(count) do |index|
      slug = "studio-#{developer.first.to_s.parameterize}-#{player.id}-#{Catalog::Card.count}-#{index}"
      card = Catalog::Card.create!(source_key: "src:#{slug}", slug:, release_date: Date.new(2020, 1, 1), developers: developer,
        image_url: "https://images.example.test/#{slug}.jpg", store_url: "https://store.example.test/#{slug}")
      hold(player, published_edition(season, card.id, index + 1))
      card
    end
  end

  def most_copies(player = @player) = capsule_metric(:most_copies_of_a_game, player)

  def most_studio_games(player = @player) = capsule_metric(:most_games_of_a_studio, player)

  test "copies of a game are summed across its editions, reserved ones included" do
    hold(@player, @common, 2)
    hold_edition(card_id_of(@common), 2, reserved: 1)
    hold(@player, @uncommon, 3)
    hold(@other, @common, 9)

    assert_equal 4, most_copies
    assert_equal 9, most_copies(@other)
    assert_equal 0, most_copies(accounts_players(:banned))
  end

  test "Diversified Portfolio is granted at five copies over two editions and refused at four" do
    hold(@player, @common, 2)
    hold_edition(card_id_of(@common), 2)
    assert_equal :not_reached, grant(:diversified_portfolio).failure

    Game::Holding.find_by!(player_id: @player.id, card_season_id: @common).update!(quantity: 3)
    assert_equal :diversified_portfolio, grant(:diversified_portfolio).value!.key
  end

  test "the studio is the card's first developer normalised as studio sets do" do
    studio_games(4, developer: [ "Valve" ])
    studio_games(2, developer: [ "Valve Corporation", "Someone Else" ])
    studio_games(1, developer: [ "VALVE, Inc." ])
    studio_games(1, developer: [ "Valve™" ])
    studio_games(3, developer: [ "Someone Else", "Valve" ])
    studio_games(2, developer: [])

    assert_equal 8, most_studio_games
  end

  test "held games of a studio count once however many editions and copies, and only while held" do
    games = studio_games(3)
    hold_edition(games.first.id, 2)
    Game::Holding.where(player_id: @player.id).where(card_season_id: Catalog::CardSeason.where(card_id: games.last.id).select(:id)).update_all(quantity: 0)

    assert_equal 2, most_studio_games
    assert_equal 0, most_studio_games(@other)
  end

  test "Market Concentration is granted at ten games of one studio and refused at nine" do
    studio_games(9, developer: [ "Acme Studios" ])
    studio_games(5, developer: [ "Other House" ])
    assert_equal :not_reached, grant(:market_concentration).failure

    studio_games(1, developer: [ "Acme Studios, Ltd." ])
    assert_equal :market_concentration, grant(:market_concentration).value!.key
  end

  def pioneer(card_season_id, player: @player)
    Game::FirstDiscovery.where(card_season_id:).delete_all
    Game::FirstDiscovery.create!(card_season_id:, player_id: player.id, discovered_at: Time.current)
  end

  def repost_entry(card_season_id, player: @player)
    Game::FeedEntry.record_repost(player_id: player.id, card_season_id:, at: Time.current)
  end

  def accepted_trades(count, proposer: @player, recipient: @other)
    low, high = [ proposer.id, recipient.id ].minmax
    count.times do
      Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: proposer.id, recipient_id: recipient.id, status: "accepted",
        proposed_at: 2.hours.ago, expires_at: 1.day.from_now, closed_at: 1.hour.ago)
    end
  end

  test "First Claim is granted for a first discovery row and refused when other players hold them all" do
    assert_equal 0, capsule_metric(:first_discoveries)
    assert_equal :not_reached, grant(:first_claim_all_rights_reserved).failure

    pioneer(@common)
    pioneer(@uncommon, player: @other)

    assert_equal 1, capsule_metric(:first_discoveries)
    assert_equal :first_claim_all_rights_reserved, grant(:first_claim_all_rights_reserved).value!.key
  end

  test "A Discovery of Ours counts a repost of a card-season the player pioneered, and not one someone else pioneered" do
    pioneer(@uncommon, player: @other)
    repost_entry(@uncommon)
    assert_equal 0, capsule_metric(:pioneered_reposts)
    assert_equal :not_reached, grant(:a_discovery_of_ours).failure

    pioneer(@common)
    repost_entry(@common, player: @other)
    assert_equal 0, capsule_metric(:pioneered_reposts)

    repost_entry(@common)
    assert_equal 1, capsule_metric(:pioneered_reposts)
    assert_equal :a_discovery_of_ours, grant(:a_discovery_of_ours).value!.key
  end

  test "A Strictly Professional Relationship needs three accepted trades with one partner, not three partners" do
    third = accounts_players(:banned)
    accepted_trades(1)
    accepted_trades(1, proposer: @other, recipient: @player)
    accepted_trades(1, recipient: third)
    accepted_trades(1, proposer: @other, recipient: third)
    assert_equal 2, capsule_metric(:most_trades_with_a_partner)
    assert_equal :not_reached, grant(:a_strictly_professional_relationship).failure

    accepted_trades(1, proposer: @other, recipient: @player)
    assert_equal 3, capsule_metric(:most_trades_with_a_partner)
    assert_equal 3, capsule_metric(:most_trades_with_a_partner, @other)
    assert_equal :a_strictly_professional_relationship, grant(:a_strictly_professional_relationship).value!.key
  end

  test "open trades and declined ones do not count toward a partner" do
    accepted_trades(2)
    low, high = [ @player.id, @other.id ].minmax
    %w[open declined cancelled expired].each do |status|
      Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: @player.id, recipient_id: @other.id, status:,
        proposed_at: 2.hours.ago, expires_at: 1.day.from_now)
    end

    assert_equal 2, capsule_metric(:most_trades_with_a_partner)
  end

  test "opening a card nobody found before unlocks First Claim, and a repost of it unlocks A Discovery of Ours" do
    Game::FirstDiscovery.where(card_season_id: @common).delete_all

    open_with_jobs([ @common ] * 5)
    assert_includes unlocked, "first_claim_all_rights_reserved"
    assert_not_includes unlocked, "a_discovery_of_ours"

    perform_enqueued_jobs { Game::RepostCard.new.call(player: @player, card_season_id: @common).value! }
    assert_includes unlocked, "a_discovery_of_ours"
  end

  def reveal_modes(modes, player: @player, from: Time.utc(2026, 1, 1))
    modes.each_with_index do |mode, index|
      create_pack(player, cards: commons, opened_at: from + index.minutes).update_columns(reveal_mode: mode)
    end
  end

  def reveal_streak(metric, player = @player) = capsule_metric(metric, player)

  test "the reveal streaks are the longest runs of opened capsules of any kind revealed one way, in opening order" do
    reveal_modes(%w[all all one_by_one all all all one_by_one one_by_one])
    assert_equal 3, reveal_streak(:reveal_all_streak)
    assert_equal 2, reveal_streak(:reveal_one_by_one_streak)

    assert_equal 0, reveal_streak(:reveal_all_streak, @other)
    assert_equal 0, reveal_streak(:reveal_one_by_one_streak, @other)
  end

  test "a capsule without a reveal mode breaks both reveal streaks" do
    reveal_modes(%w[all all all] + [ nil ] + %w[all all])
    reveal_modes(%w[one_by_one one_by_one] + [ nil ] + %w[one_by_one], from: Time.utc(2026, 2, 1))
    assert_equal 3, reveal_streak(:reveal_all_streak)
    assert_equal 2, reveal_streak(:reveal_one_by_one_streak)
  end

  test "the reveal streaks count capsules of every kind, ignore unopened ones and follow opened_at" do
    later = Time.utc(2026, 6, 1)
    %i[regular bonus reward].each_with_index do |kind, index|
      create_pack(@player, kind:, cards: commons(kind), opened_at: later + index.minutes).update_columns(reveal_mode: "all")
    end
    create_pack(@player, cards: commons).update_columns(reveal_mode: "all")
    create_pack(@player, cards: commons, opened_at: later - 1.day).update_columns(reveal_mode: "one_by_one")
    create_pack(@player, cards: commons, opened_at: later + 1.day).update_columns(reveal_mode: "all")

    assert_equal 4, reveal_streak(:reveal_all_streak)
    assert_equal 1, reveal_streak(:reveal_one_by_one_streak)
  end

  test "the reveal achievements are granted at exactly ten capsules in a row and refused at nine" do
    reveal_modes(%w[all] * 9)
    reveal_modes(%w[one_by_one] * 9, from: Time.utc(2026, 2, 1))
    assert_equal :not_reached, grant(:streamlined_opening_procedure).failure
    assert_equal :not_reached, grant(:diligence_beyond_the_call_of_duty).failure

    reveal_modes(%w[all] * 10, player: @other)
    reveal_modes(%w[one_by_one] * 10, player: @other, from: Time.utc(2026, 2, 1))
    assert_equal :streamlined_opening_procedure, grant(:streamlined_opening_procedure, player: @other).value!.key
    assert_equal :diligence_beyond_the_call_of_duty, grant(:diligence_beyond_the_call_of_duty, player: @other).value!.key
  end

  test "a run of nine, a capsule without a mode and a run of nine never reach ten" do
    reveal_modes(%w[all] * 9 + [ nil ] + %w[all] * 9)

    assert_equal 9, reveal_streak(:reveal_all_streak)
    assert_equal :not_reached, grant(:streamlined_opening_procedure).failure
  end

  test "capsules opened before the reveal mode was recorded grant neither achievement" do
    reveal_modes([ nil ] * 12)

    assert_equal 0, reveal_streak(:reveal_all_streak)
    assert_equal 0, reveal_streak(:reveal_one_by_one_streak)
    assert_equal :not_reached, grant(:streamlined_opening_procedure).failure
    assert_equal :not_reached, grant(:diligence_beyond_the_call_of_duty).failure
  end

  test "revealing the tenth capsule with Reveal all grants Streamlined Opening Procedure with a toast in each locale" do
    reveal_modes(%w[all] * 9 + [ nil ])
    assert_empty unlocked

    latest = Game::Pack.where(player_id: @player.id).order(:opened_at, :id).last
    perform_enqueued_jobs { Game::RecordReveal.new.call(player: @player, token: latest.token, mode: "all").value! }

    assert_includes unlocked, "streamlined_opening_procedure"
    assert_equal 1, toasts(@player, :fr).count { it.include?("ouverture simplifiée") }
    assert_equal 1, toasts(@player, :en).count { it.include?("Streamlined Opening Procedure") }
  end

  test "the grant re-reads only its achievement's metric" do
    opened_packs(1)

    assert_equal [ [ :packs_opened ] ], progress_reads { grant(:first_booster).value! }
  end

  test "the grant job reads only the metrics of achievements not yet unlocked, and nothing once all are" do
    opened_packs(1, cards: [ @rare, @epic ] + [ @common ] * 3)
    Game::AchievementUnlock.record(@player.id, :statistical_non_compliance, Time.current)

    reads = progress_reads { Game::GrantAchievementsJob.perform_now(@player.id) }

    assert_not_includes reads.first, :two_rare_or_better_capsules
    assert_equal (Game::AchievementProgress::METRICS - [ :two_rare_or_better_capsules ]).sort, reads.first.sort
    assert_equal %w[statistical_non_compliance first_booster packaging_irregularity], unlocked

    Game::Achievements::CATALOGUE.each { Game::AchievementUnlock.record(@player.id, it.key, Time.current) }
    assert_equal [ [] ], progress_reads { Game::GrantAchievementsJob.perform_now(@player.id) }
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

    assert_equal %w[first_booster packaging_irregularity excellence_in_mediocrity diversified_portfolio], unlocked
    assert_equal unlocked.map { { player_id: @player.id, achievement: it } }, unlock_events.map(&:data)
    toasts = broadcasts(PlayerStream.name(@player, :fr)).map { ActiveSupport::JSON.decode(it) }
    assert_equal 4, toasts.size
    assert toasts.all? { it.include?("Succès débloqué") }
    assert_equal 1, toasts.count { it.include?("Première acquisition approuvée") }
    assert_equal 4, broadcasts(PlayerStream.name(@player, :en)).count { it.include?("Achievement unlocked") }
    assert_no_broadcasts PlayerStream.name(@other, :fr)
  end

  test "an Épique pulled unlocks the first Épique; a Légendaire alone unlocks the first Légendaire only" do
    open_with_jobs([ @legendary ] + [ @common ] * 4)

    assert_equal %w[first_booster first_legendary packaging_irregularity], unlocked

    open_with_jobs([ @epic ] + [ @common ] * 4)

    assert_includes unlocked, "first_epic"
  end

  test "the tenth opening unlocks ten boosters once, and the eleventh nothing more" do
    opened_packs(9)
    travel 1.minute

    open_with_jobs([ @common ] * 5)
    assert_equal %w[first_booster boosters_10 packaging_irregularity excellence_in_mediocrity luck_is_a_marketing_concept diversified_portfolio], unlocked

    assert_no_difference -> { unlock_events.size } do
      open_with_jobs([ @common ] * 5)
    end
    assert_equal %w[first_booster boosters_10 packaging_irregularity excellence_in_mediocrity luck_is_a_marketing_concept diversified_portfolio], unlocked
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

  test "every trigger enqueues the grant for its players" do
    data = { player_id: @player.id, proposer_id: @player.id, recipient_id: @other.id, seller_id: @player.id, winner_id: @other.id }

    assert_enqueued_jobs 11, only: Game::GrantAchievementsJob do
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

    assert_equal %w[first_booster packaging_irregularity excellence_in_mediocrity], unlocked
    assert_equal 3, unlock_events.size
    assert_empty unlocked(banned)
  end

  test "the account's deletion deletes its unlocks" do
    opened_packs(1)
    opened_packs(1, player: @other)
    [ @player, @other ].each { Game::GrantAchievementsJob.perform_now(it.id) }

    Accounts::DeletePlayer.new.call(player: @player).value!

    assert_empty unlocked
    assert_equal %w[first_booster packaging_irregularity excellence_in_mediocrity], unlocked(@other)
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
    [ @player, @other, @banned ].each { create_pack(it, cards: [ fixture_tier_ids.first ] * Game::Pack::SIZE, opened_at: Time.current) }
    create_pack(@player, cards: [ fixture_tier_ids.last ] * 5, opened_at: Time.current)
    Game::Holding.create!(player_id: @player.id, card_season_id: fixture_tier_ids.last, quantity: 5)
  end

  def unlocked = Game::AchievementUnlock.pluck(:player_id, :achievement).sort

  def expected
    (%w[first_booster first_legendary statistical_non_compliance packaging_irregularity excellence_in_mediocrity diversified_portfolio].map { [ @player.id, it ] } +
      %w[first_booster packaging_irregularity excellence_in_mediocrity].map { [ @other.id, it ] }).sort
  end

  def run_task = rake_task("game:backfill_achievements").execute

  test "players in good standing get what they met, silently, once however often it runs" do
    assert_no_enqueued_jobs(only: PlayerStreamJob) do
      2.times { Game::BackfillAchievementsJob.perform_now }
    end

    assert_equal expected, unlocked
    events = Rails.configuration.event_store.read.of_type(Game::AchievementUnlocked).to_a
    assert_equal 9, events.size
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

    assert_equal %w[first_booster packaging_irregularity excellence_in_mediocrity].map { [ @other.id, it ] }.sort, unlocked
  ensure
    Game::GrantAchievementsJob.define_singleton_method(:grant, grant)
  end

  test "the rake task runs the backfill and says so" do
    output, = capture_io { 2.times { run_task } }

    assert_equal expected, unlocked
    assert_match "game:backfill_achievements", output
  end
end

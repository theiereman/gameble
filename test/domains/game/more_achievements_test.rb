require "test_helper"
require_relative "../../support/custom_sets"
require_relative "../../support/feed_reactions"
require_relative "../../support/game_packs"
require_relative "../../support/game_sets"
require_relative "../../support/holdings"

class Game::MoreAchievementsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include CustomSets
  include FeedReactions
  include GamePacks
  include GameSets
  include Holdings

  NOW = Time.utc(2026, 11, 4, 12)
  THIS_WEEK = Date.new(2026, 11, 2)

  setup do
    travel_to NOW
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def metric(name, player = @player) = Game::AchievementProgress.call(player, [ name ]).fetch(name)
  def grant(key, player = @player) = Game::GrantAchievement.new.call(player:, achievement: key)
  def unlocked(player = @player) = Game::AchievementUnlock.where(player_id: player.id).pluck(:achievement)
  def member(number, **attributes) = Accounts::Player.create!(steam_id: (76561197960900000 + number).to_s, **attributes)
  def weeks_ago(count) = THIS_WEEK - (7 * count)
  def grant_jobs = enqueued_jobs.select { it[:job] == Game::GrantAchievementsJob }.map { it[:args].first }
  def card_ids_of(card_season_ids) = Catalog::CardSeason.where(id: card_season_ids).order(:id).pluck(:card_id)

  def befriend(one, two)
    low, high = [ one.id, two.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def luck(player, week_start, z_score)
    Game::Fortune.insert_all!([ { player_id: player.id, week_start:, regular_packs: 1, actual_points: (z_score * 100).round,
      expected_points: 0, variance: 10_000, created_at: NOW, updated_at: NOW } ])
  end

  def trade_entry(proposer, recipient)
    low, high = [ proposer.id, recipient.id ].minmax
    trade = Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: proposer.id, recipient_id: recipient.id,
      status: "accepted", proposed_at: 1.hour.ago, expires_at: 1.day.from_now, closed_at: Time.current)
    common, rare = fixture_tier_ids.values_at(0, 2)
    Game::FeedEntry.record_trade(trade_id: trade.id, proposer_id: proposer.id, recipient_id: recipient.id, offer: [ rare ], request: [ common ],
      rarities: { rare => 3, common => 1 }, at: Time.current)
    Game::FeedEntry.find_by!(trade_id: trade.id)
  end

  def showcase(card_season_ids)
    card_season_ids.each_with_index { |card_season_id, position| Game::ShowcaseEntry.create!(player_id: @player.id, card_season_id:, position:) }
  end

  test "thirty-two achievements follow the first thirty, in order, each a metric and a threshold" do
    expected = [
      [ :boosters_1000, :packs_opened, 1_000 ], [ :boosters_5000, :packs_opened, 5_000 ], [ :boosters_10000, :packs_opened, 10_000 ],
      [ :reposts_10, :reposts, 10 ], [ :reposts_50, :reposts, 50 ], [ :reposts_200, :reposts, 200 ],
      [ :trades_10, :trades_accepted, 10 ], [ :trades_50, :trades_accepted, 50 ], [ :trades_100, :trades_accepted, 100 ],
      [ :picoins_50k, :picoins_held, 50_000 ], [ :picoins_500k, :picoins_held, 500_000 ], [ :picoins_1m, :picoins_held, 1_000_000 ],
      [ :friends_10, :friends, 10 ], [ :friends_25, :friends, 25 ], [ :friends_50, :friends, 50 ],
      [ :reactions_50, :reactions_given, 50 ], [ :reactions_200, :reactions_given, 200 ], [ :reactions_500, :reactions_given, 500 ],
      [ :self_assessment, :reactions_to_own_posts, 1 ], [ :viral_memo, :most_reactions_on_a_post, 10 ],
      [ :showcase_full, :showcase_cards, 5 ], [ :everything_must_go, :showcase_cleared_after_full, 1 ],
      [ :entrusted_100, :cards_entrusted, 100 ], [ :entrusted_1000, :cards_entrusted, 1_000 ],
      [ :entrusted_5000, :cards_entrusted, 5_000 ], [ :entrusted_10000, :cards_entrusted, 10_000 ],
      [ :employee_of_the_week, :verdicts_won, 1 ], [ :room_for_improvement, :last_places, 1 ],
      [ :sustained_growth, :lucky_week_streak, 3 ], [ :turnaround_plan, :unlucky_week_streak, 3 ],
      [ :statement_of_requirements, :largest_custom_set, 10 ], [ :delivered_on_schedule, :largest_completed_custom_set, 10 ]
    ]

    assert_equal expected, Game::Achievements::CATALOGUE.drop(30).first(32).map { [ it.key, it.metric, it.threshold ] }
    assert_equal [ [ :goals_10, :goals_completed, 10 ], [ :goals_25, :goals_completed, 25 ], [ :goals_50, :goals_completed, 50 ],
      [ :avatar_changed, :avatar_choices, 1 ], [ :avatar_rebrand, :avatar_choices, 5 ], [ :source_audit, :source_code_opened, 1 ],
      [ :funding_review, :support_opened, 1 ] ], Game::Achievements::CATALOGUE.last(7).map { [ it.key, it.metric, it.threshold ] }
    assert_equal 69, Game::Achievements::CATALOGUE.size
  end

  test "PiCoins held add the coins committed to bids to the available ones" do
    assert_equal 0, metric(:picoins_held)

    Game::Market::Wallet.create!(player_id: @player.id, available: 40_000, committed: 10_000)
    Game::Market::Wallet.create!(player_id: @other.id, available: 49_999)

    assert_equal 50_000, metric(:picoins_held)
    assert_equal :picoins_50k, grant(:picoins_50k).value!.key
    assert_equal :not_reached, grant(:picoins_50k, @other).failure
  end

  test "friends count the friendships on either side, never one between two other players" do
    third = member(1)
    befriend(@player, @other)
    befriend(@player, third)
    befriend(@other, third)
    befriend(member(2), member(3))

    assert_equal [ 2, 2, 2 ], [ @player, @other, third ].map { metric(:friends, it) }
  end

  test "reactions given count the entries the player reacts to, once each however often the reaction changes" do
    entries = Array.new(3) { feed_entry_of(@other) }
    entries.each { react(@player, it, "thumb").value! }
    react(@player, entries.first, "heart").value!
    react(@player, entries.last, nil).value!
    react(@other, entries.first, "gg").value!

    assert_equal 2, metric(:reactions_given)
    assert_equal 0, metric(:reactions_to_own_posts)
    assert_equal 1, metric(:reactions_to_own_posts, @other)
  end

  test "a reaction to the player's own entry is a self-assessment, re-checking the player once" do
    entry = feed_entry_of(@player)
    assert_equal 0, metric(:reactions_to_own_posts)

    react(@player, entry, "heart").value!

    assert_equal [ @player.id ], grant_jobs
    perform_enqueued_jobs
    assert_includes unlocked, "self_assessment"
  end

  test "the tenth reaction on an entry re-checks its author, who gets Viral Memo" do
    entry = feed_entry_of(@player)
    Array.new(9) { member(it) }.each { react(it, entry, "wow").value! }
    clear_enqueued_jobs
    assert_equal 9, metric(:most_reactions_on_a_post)

    perform_enqueued_jobs(only: Game::GrantAchievementsJob) { react(member(9), entry, "gg").value! }

    assert_equal 10, metric(:most_reactions_on_a_post)
    assert_includes unlocked, "viral_memo"
  end

  test "most reactions on a post is the best of the player's entries, neither their sum nor someone else's" do
    first, second = Array.new(2) { feed_entry_of(@player) }
    theirs = feed_entry_of(@other)
    reactors = Array.new(3) { member(it) }
    reactors.each { react(it, first, "thumb").value! }
    reactors.first(2).each { react(it, second, "thumb").value! }
    [ *reactors, @player ].each { react(it, theirs, "heart").value! }

    assert_equal 3, metric(:most_reactions_on_a_post)
    assert_equal 4, metric(:most_reactions_on_a_post, @other)
  end

  test "an owner's own reaction never counts toward Viral Memo" do
    entry = feed_entry_of(@player)
    [ @player, *Array.new(9) { member(it) } ].each { react(it, entry, "wow").value! }

    assert_equal 9, metric(:most_reactions_on_a_post)
    assert_equal :not_reached, grant(:viral_memo).failure
  end

  test "a trade recipient owns the trade entry: their reaction is a self-assessment and others' reactions are received" do
    entry = trade_entry(@other, @player)

    react(@player, entry, "heart").value!

    assert_equal [ @player.id, @other.id ], grant_jobs
    assert_equal [ 1, 0 ], [ @player, @other ].map { metric(:reactions_to_own_posts, it) }
    assert_equal [ 0, 0 ], [ @player, @other ].map { metric(:most_reactions_on_a_post, it) }

    react(@other, entry, "gg").value!
    Array.new(10) { member(it) }.each { react(it, entry, "thumb").value! }

    assert_equal [ 1, 1 ], [ @player, @other ].map { metric(:reactions_to_own_posts, it) }
    assert_equal [ 10, 10 ], [ @player, @other ].map { metric(:most_reactions_on_a_post, it) }
    assert_equal :viral_memo, grant(:viral_memo).value!.key
  end

  test "a reaction re-checks the reactor and the entry's owners, each once, only the reactor without an owner, and no one once removed" do
    third = member(1)
    rechecked = {
      [ @other.id, nil ] => [ @player.id, @other.id ], [ @player.id, nil ] => [ @player.id ], [ nil, nil ] => [ @player.id ],
      [ @other.id, @player.id ] => [ @player.id, @other.id ], [ @other.id, third.id ] => [ @player.id, @other.id, third.id ]
    }

    rechecked.each do |(author_id, partner_id), players|
      clear_enqueued_jobs
      Game::Handlers::Achievements.call(Game::FeedEntryReacted.new(data: { player_id: @player.id, feed_entry_id: 1, kind: "thumb", author_id:, partner_id: }))
      assert_equal players, grant_jobs, [ author_id, partner_id ].inspect
    end

    clear_enqueued_jobs
    Game::Handlers::Achievements.call(Game::FeedEntryReacted.new(data: { player_id: @player.id, feed_entry_id: 1, kind: nil, author_id: @other.id, partner_id: nil }))
    assert_empty grant_jobs
  end

  test "an accepted invitation re-checks both friends; the showcase, the Archives and custom sets re-check their player" do
    Game::Handlers::Achievements.call(Game::InvitationAccepted.new(data: { invitation_id: 1, sender_id: @player.id, recipient_id: @other.id }))
    assert_equal [ @player.id, @other.id ], grant_jobs

    [ Game::Market::CardsEntrusted, Game::ShowcaseCardAdded, Game::ShowcaseCardRemoved, Game::CustomSetCreated, Game::CustomSetEdited ].each do |event|
      clear_enqueued_jobs
      Game::Handlers::Achievements.call(event.new(data: { player_id: @player.id }))
      assert_equal [ @player.id ], grant_jobs, event.name
    end
  end

  test "a showcase of five cards is full, four is not" do
    showcase(fixture_tier_ids.first(4))
    assert_equal :not_reached, grant(:showcase_full).failure

    Game::ShowcaseEntry.create!(player_id: @player.id, card_season_id: fixture_tier_ids.last, position: 4)

    assert_equal 5, metric(:showcase_cards)
    assert_equal :showcase_full, grant(:showcase_full).value!.key
  end

  test "an empty showcase counts as cleared only once the showcase has been full" do
    assert_equal 0, metric(:showcase_cleared_after_full)

    showcase(fixture_tier_ids)
    grant(:showcase_full).value!
    assert_equal 0, metric(:showcase_cleared_after_full)

    Game::ShowcaseEntry.where(player_id: @player.id).delete_all

    assert_equal 1, metric(:showcase_cleared_after_full)
    assert_equal 0, metric(:showcase_cleared_after_full, @other)
    assert_equal :everything_must_go, grant(:everything_must_go).value!.key
  end

  test "filling the showcase grants Point-of-Sale Layout, and emptying it then grants Everything Must Go" do
    fixture_tier_ids.each { hold(@player, it) }

    perform_enqueued_jobs(only: Game::GrantAchievementsJob) do
      fixture_tier_ids.each { Game::AddToShowcase.new.call(player: @player, card_season_id: it).value! }
    end
    assert_includes unlocked, "showcase_full"
    assert_not_includes unlocked, "everything_must_go"

    perform_enqueued_jobs(only: Game::GrantAchievementsJob) do
      fixture_tier_ids.each { Game::RemoveFromShowcase.new.call(player: @player, card_season_id: it).value! }
    end
    assert_includes unlocked, "everything_must_go"
  end

  test "cards entrusted add up every deposit of the player's, never someone else's" do
    common, rare = fixture_tier_ids.values_at(0, 2)
    Game::Market::ArchiveDeposit.add(@player.id, { common => 60, rare => 30 }, NOW)
    Game::Market::ArchiveDeposit.add(@player.id, { common => 10 }, NOW)
    Game::Market::ArchiveDeposit.add(@other.id, { common => 99 }, NOW)

    assert_equal 100, metric(:cards_entrusted)
    assert_equal :entrusted_100, grant(:entrusted_100).value!.key
    assert_equal :not_reached, grant(:entrusted_100, @other).failure
  end

  test "verdicts won count the weeks the player was named the luckiest" do
    Game::FeedEntry.record_verdict(player_id: @player.id, week_start: weeks_ago(1), now: NOW)

    assert_equal [ 1, 0 ], [ @player, @other ].map { metric(:verdicts_won, it) }
    assert_equal :employee_of_the_week, grant(:employee_of_the_week).value!.key
  end

  test "last places count the completed weeks the player ended last of at least two ranked players" do
    luck(@player, weeks_ago(2), -2.0)
    assert_equal 0, metric(:last_places)

    luck(@other, weeks_ago(2), 1.0)
    luck(@player, weeks_ago(1), -1.0)
    luck(@other, weeks_ago(1), -3.0)
    luck(@player, weeks_ago(3), -1.0)
    luck(member(1), weeks_ago(3), -2.0)

    assert_equal [ 1, 1 ], [ @player, @other ].map { metric(:last_places, it) }
    assert_equal :room_for_improvement, grant(:room_for_improvement).value!.key
  end

  test "of two players tied at the bottom, the last is the one the ranking puts last" do
    luck(member(1), weeks_ago(1), 3.0)
    tied = [ @player, @other ].sort_by(&:id)
    tied.each { luck(it, weeks_ago(1), -1.0) }

    assert_equal tied.last.id, Game::Fortune.where(week_start: weeks_ago(1)).ranked.last.player_id
    assert_equal [ 0, 1 ], tied.map { metric(:last_places, it) }
  end

  test "the week in play, the all-time row and an unlisted rival never make a last place" do
    [ THIS_WEEK, nil ].each do |week_start|
      luck(@player, week_start, -2.0)
      luck(@other, week_start, 1.0)
    end
    luck(@player, weeks_ago(1), -2.0)
    luck(member(1, visibility: :private), weeks_ago(1), 1.0)
    luck(@player, weeks_ago(2), -2.0)
    luck(accounts_players(:banned), weeks_ago(2), 1.0)

    assert_equal 0, metric(:last_places)
  end

  test "the lucky streak counts consecutive completed weeks above zero, a week without capsules breaking it" do
    [ 4, 3, 1 ].each { luck(@player, weeks_ago(it), 1.0) }

    assert_equal 2, metric(:lucky_week_streak)
  end

  test "the week in play never counts toward a streak" do
    [ 2, 1, 0 ].each { luck(@player, weeks_ago(it), 1.0) }
    luck(@player, nil, 1.0)

    assert_equal 2, metric(:lucky_week_streak)
    assert_equal :not_reached, grant(:sustained_growth).failure
  end

  test "three weeks above zero grant Sustained Growth and three below Turnaround Plan, a week at zero breaking both" do
    { 6 => -1.0, 5 => -1.0, 4 => -1.0, 3 => 1.0, 2 => 1.0, 1 => 1.0 }.each { |weeks, z_score| luck(@player, weeks_ago(weeks), z_score) }
    { 3 => 1.0, 2 => 0.0, 1 => 1.0 }.each { |weeks, z_score| luck(@other, weeks_ago(weeks), z_score) }

    assert_equal [ 3, 3 ], [ metric(:lucky_week_streak), metric(:unlucky_week_streak) ]
    assert_equal [ 1, 0 ], [ metric(:lucky_week_streak, @other), metric(:unlucky_week_streak, @other) ]
    assert_equal :sustained_growth, grant(:sustained_growth).value!.key
    assert_equal :turnaround_plan, grant(:turnaround_plan).value!.key
  end

  test "a Steam library set of forty held games is no custom set" do
    editions = unheld_cards(40)
    create_library_set(@player, card_ids: card_ids_of(editions))
    editions.each { hold(@player, it) }

    assert_equal [ 0, 0 ], [ metric(:largest_custom_set), metric(:largest_completed_custom_set) ]
  end

  test "the largest custom set counts its games, held or not, and the largest completed one only a set held in full" do
    editions = unheld_cards(10)
    games = card_ids_of(editions)
    create_custom_set(@player, name: "Ten", card_ids: games)
    create_custom_set(@player, name: "Five", card_ids: games.first(5))
    editions.first(9).each { hold(@player, it) }

    assert_equal [ 10, 5 ], [ metric(:largest_custom_set), metric(:largest_completed_custom_set) ]
    assert_equal :statement_of_requirements, grant(:statement_of_requirements).value!.key
    assert_equal :not_reached, grant(:delivered_on_schedule).failure

    hold(@player, editions.last)

    assert_equal 10, metric(:largest_completed_custom_set)
    assert_equal :delivered_on_schedule, grant(:delivered_on_schedule).value!.key
  end

  test "Monday's verdict job re-checks every player with a fortune row last week, with a public winner or none" do
    luck(@player, weeks_ago(1), 2.0)
    luck(@other, weeks_ago(1), -1.0)
    luck(accounts_players(:administrator), THIS_WEEK, 1.0)
    luck(accounts_players(:administrator), nil, 1.0)

    Game::PublishWeeklyVerdictJob.perform_now

    assert_equal [ @player.id ], Game::FeedEntry.where(kind: "verdict").pluck(:player_id)
    assert_equal [ @player.id, @other.id ].sort, grant_jobs.sort

    clear_enqueued_jobs
    hidden = [ member(1, visibility: :friends_only), member(2, visibility: :private) ]
    hidden.each { luck(it, weeks_ago(1), 5.0) }
    Game::Fortune.where(player_id: [ @player.id, @other.id ]).delete_all

    Game::PublishWeeklyVerdictJob.perform_now

    assert_equal hidden.map(&:id).sort, grant_jobs.sort
  end

  test "Monday's verdict grants the winner Employee of the Week and the last Room for Improvement" do
    luck(@player, weeks_ago(1), 2.0)
    luck(@other, weeks_ago(1), -1.0)

    perform_enqueued_jobs(only: Game::GrantAchievementsJob) { Game::PublishWeeklyVerdictJob.perform_now }

    assert_includes unlocked(@player), "employee_of_the_week"
    assert_includes unlocked(@other), "room_for_improvement"
    assert_not_includes unlocked(@player), "room_for_improvement"
  end

  test "avatar choices count the player's own events, a repeated choice included" do
    base = metric(:avatar_choices)
    2.times { Rails.configuration.event_store.publish(Game::AvatarChosen.new(data: { player_id: @player.id, avatar: "x" })) }
    Rails.configuration.event_store.publish(Game::AvatarChosen.new(data: { player_id: @other.id, avatar: "x" }))

    assert_equal base + 2, metric(:avatar_choices)
  end

  test "the first click on a link is kept, a repeat writes nothing and publishes nothing" do
    assert_equal [ 0, 0 ], [ metric(:source_code_opened), metric(:support_opened) ]

    Game::MarkLinkOpened.new.call(player: @player, link: "source_code").value!
    first = Game::PlayerState.find_by!(player_id: @player.id).source_code_opened_at
    travel 1.hour
    assert_no_difference -> { Rails.configuration.event_store.read.of_type(Game::LinkOpened).count } do
      Game::MarkLinkOpened.new.call(player: @player, link: "source_code").value!
    end

    assert_equal first, Game::PlayerState.find_by!(player_id: @player.id).source_code_opened_at
    assert_equal [ 1, 0 ], [ metric(:source_code_opened), metric(:support_opened) ]
  end

  test "an unknown link fails and writes nothing" do
    assert_equal :unknown_link, Game::MarkLinkOpened.new.call(player: @player, link: "other").failure
    assert_nil Game::PlayerState.find_by(player_id: @player.id)&.source_code_opened_at
    assert_nil Game::PlayerState.find_by(player_id: @player.id)&.support_opened_at
  end

  test "the new achievements are met at their thresholds" do
    progress = { goals_completed: 25, avatar_choices: 5, source_code_opened: 1, support_opened: 0 }
    met = %i[goals_10 goals_25 avatar_changed avatar_rebrand source_audit]
    assert_equal met, met.select { Game::Achievements.find(it).met?(progress) }
    assert_not Game::Achievements.find(:goals_50).met?(progress)
    assert_not Game::Achievements.find(:funding_review).met?(progress)
  end

  test "the deploy backfill grants what history already meets, without a toast" do
    Game::FeedEntry.record_verdict(player_id: @player.id, week_start: weeks_ago(1), now: NOW)
    befriend(@player, @other)

    assert_no_enqueued_jobs(only: PlayerStreamJob) { Game::BackfillAchievementsJob.perform_now }

    assert_includes unlocked, "employee_of_the_week"
  end
end

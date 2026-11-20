require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# During the alpha a duel grants nothing. Léa wins a live duel against Hugo and a practice duel against the bot, with no
# automatic move: neither result has a capsule line, no achievement toast shows, and her special reserve stays empty.
class DuelRewardsSystemTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include SteamSignIn
  include LiveDuels

  PHONE = [ 390, 844 ].freeze

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @lea.update!(persona_name: "Léa")
    @hugo.update!(persona_name: "Hugo")
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    Game::DeckCard.where(deck_id: Game::Deck.where(player_id: @lea.id).select(:id)).pluck(:card_season_id)
      .each { set_percentiles(it, **Game::DuelStat::STATS.index_with { 100 }) }
    Game::MarkAllocationSeen.new.call(player: @lea).value!
    reduced_motion("reduce")
  end

  teardown do
    reduced_motion("")
    resize_to(*SCREEN_SIZE)
  end

  def reduced_motion(value)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: } ])
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def listening
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    assert_no_selector "turbo-cable-stream-source:not([connected])", visible: :all
  end

  def deliver = perform_enqueued_jobs(only: [ PlayerStreamJob, DuelStreamJob, Game::GrantAchievementsJob ])

  def assert_no_reward_shown
    assert_no_selector "#duel-capsule-line"
    assert_no_text "DUEL CAPSULE WON"
    assert_no_text "Duel capsule already won today."
    assert_selector "#duel-result a", text: "Send feedback"
    assert_no_selector "#toasts .toast"
  end

  # The practice duel replays the live one: the bot holds Hugo's deck in his draw order and Léa hers, Léa calls first,
  # and both seats play the moves the rules would play, so Léa wins it as she won the live duel.
  def replay_as_practice(live)
    practice = Game::StartPracticeDuel.new.call(player: @lea, deck_token: deck_token_of(@lea)).value!
    Game::Duel.where(id: practice.id).update_all(live.slice(:challenger_cards, :opponent_cards, :challenger_draw_order,
      :opponent_draw_order).merge(first_caller: "challenger"))
    10.times { play_round(practice) }
    Game::Duel.find(practice.id)
  end

  test "a live win and a practice win with no automatic move grant no capsule and no achievement" do
    duel = start_duel(@lea, @hugo)
    Game::Duel.where(id: duel.id).update_all(first_caller: "challenger")
    resize_to(*PHONE)
    sign_in @lea
    visit duel_path(locale: :en, token: duel.token)
    assert_selector "#duel-board[data-move-number='1']"
    listening

    assert_no_enqueued_jobs only: Game::GrantAchievementsJob do
      10.times { play_round(duel) }
    end
    deliver

    assert_selector "#duel-result-heading", text: /Win against Hugo/
    assert_no_reward_shown

    practice = nil
    assert_no_enqueued_jobs only: Game::GrantAchievementsJob do
      practice = replay_as_practice(Game::Duel.find(duel.id))
    end
    assert_equal [ true, "finished", "challenger" ], [ practice.practice, practice.state, practice.result ]
    deliver
    visit duel_path(locale: :en, token: practice.token)

    assert_selector "#duel-result-heading", text: /Win against/
    assert_no_reward_shown

    visit booster_path(locale: :en)
    assert_selector "[role=tab][data-reserve=special][disabled]", text: /SPECIAL · 0/
    assert_empty Game::Pack.where(kind: "duel")
    assert_empty Game::AchievementUnlock.where(player_id: [ @lea.id, @hugo.id ])
  end
end

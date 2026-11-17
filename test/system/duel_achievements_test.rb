require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# A player whose duel ends with their first win sees the toasts of the two achievements it earns, live, and both
# tiles show earned on the achievements screen.
class DuelAchievementsTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include SteamSignIn
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    befriend(@lea, @hugo)
    lea_deck = complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    Game::DeckCard.where(deck_id: lea_deck.id).pluck(:card_season_id).each do |id|
      set_percentiles(id, **Game::DuelStat::STATS.index_with { 100 })
    end
    @duel = start_duel(@lea, @hugo)
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  test "the first win shows the toasts of First Dispute Settled Amicably and Competitive Advantage Observed, and both tiles earned" do
    sign_in @lea
    visit duel_path(locale: :en, token: @duel.token)
    assert_selector "#duel-board[data-move-number='1']"
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    assert_no_selector "turbo-cable-stream-source:not([connected])", visible: :all

    10.times { play_round(@duel) }
    perform_enqueued_jobs(only: Game::GrantAchievementsJob)
    perform_enqueued_jobs(only: [ PlayerStreamJob, DuelStreamJob ])

    assert_equal "challenger", Game::Duel.find(@duel.id).result
    assert_selector ".toast", text: "First Dispute Settled Amicably"
    assert_selector ".toast", text: "Competitive Advantage Observed"

    visit achievements_path(locale: :en)
    %w[first_dispute_settled_amicably competitive_advantage_observed].each do |key|
      assert_selector "#achievement-#{key}:not(.achievement--locked)"
    end
    assert_selector "#achievement-dominant_position.achievement--locked"
  end
end

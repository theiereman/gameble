require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# The finished duel's capsule line: the winner reads which of the three cases applied, linked to the capsule screen
# when the capsule was granted; the loser reads nothing.
class DuelCapsuleLineTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    Game::DeckCard.where(deck_id: Game::Deck.where(player_id: @lea.id).select(:id)).pluck(:card_season_id)
      .each { set_percentiles(it, **Game::DuelStat::STATS.index_with { 100 }) }
    @duel = start_duel(@lea, @hugo)
    10.times { play_round(@duel) }
  end

  def visit_as(player, locale)
    sign_in(player)
    get duel_path(locale:, token: @duel.token)
    assert_response :success
  end

  test "a granted capsule is a panel linking to the capsule screen with the duel canister" do
    visit_as(@lea, :en)

    assert_select "#duel-capsule-line .duel-capsule a[href='#{booster_path(locale: :en)}']", text: "DUEL CAPSULE WON" do
      assert_select "svg.duel-capsule__icon"
    end
    visit_as(@lea, :fr)
    assert_select "#duel-capsule-line .duel-capsule a", text: "CAPSULE DE DUEL GAGNÉE"
  end

  test "a win with an automatic move of the winner, or after another win that day, says why there is no capsule" do
    { "automatic_move" => %w[en fr], "already_won_today" => %w[en fr] }.each do |capsule, locales|
      Game::Duel.where(id: @duel.id).update_all(capsule:)

      locales.each do |locale|
        visit_as(@lea, locale.to_sym)
        assert_select "#duel-capsule-line p.duel-capsule__none", text: I18n.t("duels.board.capsule.#{capsule}", locale:)
        assert_select "#duel-capsule-line a", 0
      end
    end
  end

  test "the loser reads no capsule line" do
    visit_as(@hugo, :en)

    assert_select "#duel-capsule-line", 1
    assert_select "#duel-capsule-line *", 0
  end
end

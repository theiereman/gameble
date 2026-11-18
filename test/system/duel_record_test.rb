require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# Léa wins one duel against Hugo and loses another: her profile's activity shows 1 win and 1 loss, her Duels screen shows
# the record and the two last duels, a row opens its result, and the rules link opens the duels section of How it works.
class DuelRecordSystemTest < ApplicationSystemTestCase
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
    Game::MarkAllocationSeen.new.call(player: @lea).value!
  end

  teardown { resize_to(*SCREEN_SIZE) }

  def rate_deck_of(player, percentile)
    Game::DeckCard.where(deck_id: Game::Deck.where(player_id: player.id).select(:id)).pluck(:card_season_id)
      .each { set_percentiles(it, **Game::DuelStat::STATS.index_with { percentile }) }
  end

  def play_a_duel
    duel = start_duel(@lea, @hugo)
    10.times { play_round(duel) }
    duel
  end

  def left_of(selector) = evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().left")

  def top_of(selector) = evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().top")

  test "the profile and the Duels screen show a win and a loss, a row opens its result and the rules link opens the duels section" do
    rate_deck_of(@lea, 100)
    rate_deck_of(@hugo, 50)
    won = play_a_duel
    rate_deck_of(@lea, 50)
    rate_deck_of(@hugo, 100)
    lost = play_a_duel
    mock_steam_sign_in(@lea.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    visit me_path(locale: :en)
    assert_selector ".profile-figure", text: /Duel wins\s*1/i
    assert_selector ".profile-figure", text: /Duel losses\s*1/i
    assert_selector ".profile-figure", text: /Duel draws\s*0/i

    visit duels_path(locale: :en)
    assert_selector ".duel-record__line", text: "Duels: 1 win, 1 loss, 0 draws", visible: :all
    assert_selector ".duel-history__row", count: 2
    assert_selector ".duel-history__item:first-child", text: "Loss against Hugo"
    assert_operator top_of(".duel-history"), :>, top_of(".duel-record")

    resize_to(*PHONE)
    assert_operator top_of(".duel-history"), :>, top_of(".duel-record")
    resize_to(*SCREEN_SIZE)

    find(".duel-history__row[href='#{duel_path(locale: :en, token: won.token)}']").click
    assert_selector "#duel-result-heading", text: /Win against Hugo/
    assert_current_path duel_path(locale: :en, token: won.token)
    assert_no_selector "a[href='#{duel_path(locale: :en, token: lost.token)}']"

    visit duels_path(locale: :en)
    click_link "Duel rules"
    assert_current_path "/en/how-it-works"
    assert_equal "how-it-works-duels", URI(current_url).fragment
    assert_selector "#how-it-works-duels", text: /duels/i
    assert_text "Each player holds a hand of #{Game::DuelRules::HAND_SIZE} cards"
  end
end

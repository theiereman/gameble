require "application_system_test_case"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# The pioneer ranking: the viewer's place pinned while their row is off
# screen leads to that row on its page, and a period chip keeps focus.
class PioneerRankingTest < ApplicationSystemTestCase
  include GameSets
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @player.update!(persona_name: "Hugo")
    _season, cards = published_cards(109)
    54.times do |index|
      pioneer = Accounts::Player.create!(steam_id: (76561197960800000 + index).to_s, persona_name: "Pioneer #{index}")
      discover(pioneer, cards[index * 2, 2])
    end
    discover(@player, cards[108])
    mock_steam_sign_in(@player.steam_id)
  end

  def discover(player, card_season_ids)
    now = Time.current
    Game::FirstDiscovery.insert_all!(Array(card_season_ids).map do |card_season_id|
      { card_season_id:, player_id: player.id, discovered_at: now, created_at: now, updated_at: now }
    end)
  end

  def link_position = evaluate_script("getComputedStyle(document.querySelector('.pioneer-place__link')).position")

  def focused_id = evaluate_script("document.activeElement.id")

  test "the pinned place loads the viewer's page and focuses their row; the Total chip keeps focus and the address" do
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    resize_to(1280, 800)

    visit pioneer_ranking_path(locale: :en)

    link = find(".pioneer-place.pioneer-place--pinned a.pioneer-place__link", text: "Your place: #55, 1 discovery, go to my row")
    eventually("the place link is pinned to the viewport") { link_position == "fixed" }
    link.click

    assert_selector "li#pioneer-ranking-me", text: "Hugo"
    eventually("the viewer's row holds focus") { focused_id == "pioneer-ranking-me" }

    find("button.segmented__option[name=period][value=season]").click

    assert_selector "button.segmented__option[name=period][value=season][aria-pressed=true]", text: /\ATotal\z/i
    eventually("the pressed chip keeps focus") do
      evaluate_script("document.activeElement.matches('button[name=period][value=season][aria-pressed=true]')")
    end
    eventually("the address carries the period") { URI(current_url).query.to_s.include?("period=season") }
  end
end

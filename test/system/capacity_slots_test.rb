require "application_system_test_case"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"
require_relative "../support/market"
require_relative "../support/market_auctions"

# A player at a free limit buys the next slot where they meet it: the goal button marks the set as the new goal, and
# + NEW DECK opens the new deck's editor.
class CapacitySlotsTest < ApplicationSystemTestCase
  include GameSets
  include MarketAuctions
  include MarketSettings
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    forget_market!
    open_market!(first_opened_at: 1.day.ago)
    fund!(@player, 2_000)
  end

  def sign_in
    sign_in_browser(@player.steam_id)
  end

  test "a player with five goals buys the sixth slot from an album, and the set becomes goal 6" do
    %w[a1 a2 a3 a4 a5 a6].each { insert_set(unheld_cards(3), { complete: 3 }, key: it, params: { "theme" => it }) }
    %w[a1 a2 a3 a4 a5].each { Game::AddGoal.new.call(player: @player, kind: "theme", key: it).value! }
    sign_in

    visit library_set_path(locale: :en, kind: "theme", key: "a6")
    find("#set-album-goal .goal-button", text: "MARK AS GOAL").click
    within "dialog#slot-purchase-dialog" do
      assert_selector "h2", text: "A 6TH GOAL?"
      click_on "BUY · 500"
    end

    assert_selector "#set-album-goal .goal-button", text: "GOAL 6 · REMOVE"
    assert_selector "#set-album-goal p[role=status]", text: "A6 is your goal 6."
    assert_no_selector "dialog#slot-purchase-dialog"
    eventually("the focus should be on the goal button") do
      page.evaluate_script("document.activeElement?.matches('#set-album-goal .goal-button') === true")
    end

    visit library_path(locale: :en)
    assert_selector "#goals .goals__count", text: "6 / 6"
  end

  test "a player with three decks buys the fourth slot and lands in the new deck's editor" do
    3.times { |index| Game::CreateDeck.new.call(player: @player, name: "Deck #{index + 1}").value! }
    sign_in

    visit duels_path(locale: :en)
    find("a.deck-new").click
    within "dialog#slot-purchase-dialog" do
      assert_selector "h2", text: "A 4TH DECK?"
      click_on "BUY · 1,000"
    end

    assert_selector "#deck-editor"
    eventually("the deck name should have the focus") { page.evaluate_script("document.activeElement?.id") == "deck-name" }
    assert_equal 4, Game::Capacity.limit(@player, :deck)
  end
end

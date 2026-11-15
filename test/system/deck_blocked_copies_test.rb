require "application_system_test_case"
require_relative "../support/market"
require_relative "../support/steam_sign_in"

class DeckBlockedCopiesSystemTest < ApplicationSystemTestCase
  include MarketSettings
  include SteamSignIn

  setup do
    @hugo = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @lea.update!(persona_name: "Lea")
    low, high = [ @hugo.id, @lea.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    @portal = catalog_card_seasons(:portal_one)
    Game::Holding.create!(player_id: @hugo.id, card_season_id: @portal.id, quantity: 1, reserved: 1)
    Game::Holding.create!(player_id: @lea.id, card_season_id: catalog_card_seasons(:rare_card_one).id, quantity: 1, reserved: 0)
    deck = Game::Deck.create!(player_id: @hugo.id, name: "Vieux briscards")
    Game::DeckCard.create!(deck_id: deck.id, card_season_id: @portal.id, card_id: @portal.card_id, slot: 1)
  end

  def sign_in_hugo
    mock_steam_sign_in(@hugo.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def remove_from_decks(from:)
    find("#{from} .deck-holding button", text: /remove from decks/i).click
    within("dialog#deck-removal-portal--s1[open]") do
      assert_text(/remove portal from 1 deck\?/i)
      click_on "Remove", exact: true
    end
  end

  test "a card freed from its deck on the trade board can then be placed" do
    sign_in_hugo
    visit new_trade_path(locale: :en, friend: @lea.token)

    find(".trade-side--own .trade-add").click
    within(".trade-picker") do
      assert_selector ".trade-pick[data-key='portal--s1'] .trade-pick__reserved", text: /in a deck/i
      assert_selector ".trade-pick[data-key='portal--s1'] .deck-holding__names", text: "In: Vieux briscards"
      assert_selector ".trade-pick[data-key='portal--s1'] .trade-pick__toggle[aria-disabled='true']"
    end
    remove_from_decks(from: ".trade-pick[data-key='portal--s1']")

    assert_text "Portal is in no deck any more."
    assert_equal 0, Game::DeckCard.count
    find(".trade-side--own .trade-add").click
    within(".trade-picker") do
      assert_no_selector ".trade-pick[data-key='portal--s1'] .deck-holding"
      find(".trade-pick__toggle[aria-label^='Portal,']:not([aria-disabled])").click
      click_on "Place", exact: true
    end
    within(".trade-side--own.trade-side--editing") do
      assert_selector ".trade-card[data-key='portal--s1']"
    end
  end

  test "entrusting and selling show the decked card with its deck, and free it there" do
    open_market!
    Game::Holding.create!(player_id: @hugo.id, card_season_id: catalog_card_seasons(:common_card_one).id, quantity: 1, reserved: 0)
    sign_in_hugo

    visit new_market_entrustment_path(locale: :en, filter: { query: "" })
    within(".entrust-cell[data-ref='portal:1']") do
      assert_selector ".entrust-cell__reserved", text: /in a deck/i
      assert_selector ".deck-holding__names", text: "In: Vieux briscards"
      assert_selector ".deck-holding button", text: /remove from decks/i
    end

    visit new_market_sale_path(locale: :en)
    assert_selector ".sale-cell[data-ref='portal:1'][aria-disabled='true'] .sale-cell__decks", text: "In: Vieux briscards"
    find(".sale-cell[data-ref='portal:1']").click
    assert_selector "#listing-form[data-chosen='false']"
    remove_from_decks(from: "#sale-decked")

    assert_text "Portal is in no deck any more."
    assert_no_selector "#sale-decked .sale-decked"
    find(".sale-cell[data-ref='portal:1']:not([aria-disabled])").click
    assert_selector "#listing-form[data-chosen='true']"
  end
end

require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/market"
require_relative "../support/market_auctions"

# The delete dialog names what becomes of a player's balance, running listings and bids.
class SettingsDeleteDialogTest < ActionDispatch::IntegrationTest
  include MarketAuctions
  include MarketSettings
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    open_market!
    sign_in(@player)
  end

  test "a player with no market activity sees no market paragraph" do
    get settings_path(locale: :en)

    assert_select "dialog#delete-dialog"
    assert_select "#delete-dialog-market", 0
  end

  test "a player with a balance sees it named, in both languages" do
    fund!(@player, 5_000)

    get settings_path(locale: :en)
    assert_select "#delete-dialog-market", text: /Your balance of .*5,000.* PiCoins is destroyed without refund once your running listings are withdrawn and your bids released\./
    assert_select "#delete-confirmation[aria-describedby='delete-dialog-note delete-dialog-market delete-dialog-kept']"

    get settings_path(locale: :fr)
    assert_select "#delete-dialog-market", text: /Votre solde de .* PiCoins est détruit sans remboursement/
  end

  test "the note lists the purchases announced in the feed among the erased entries" do
    get settings_path(locale: :en)

    assert_select "#delete-dialog-note", text: /purchases announced in the feed/
    get settings_path(locale: :fr)
    assert_select "#delete-dialog-note", text: /achats annoncés dans le fil/
  end
end

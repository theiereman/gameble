require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/market"
require_relative "../support/market_auctions"

class MarketShopSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include MarketAuctions
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @rare = catalog_card_seasons(:rare_card_one)
    forget_market!
    @settings = open_market!(first_opened_at: 1.day.ago, archive_price_rare: 500)
    fund!(@player, 1_000)
    Game::Market::ArchiveStock.create!(card_season_id: @rare.id, quantity: 2)
  end

  def sign_in_and_visit_shop
    mock_steam_sign_in(@player.steam_id)
    sign_in_browser(locale: :fr)
    visit market_shop_path(locale: :fr)
  end

  def tile = find("#archive-offer-blue-depths-1 a")

  test "a player buys a copy from the confirmation, reads the result and the tile's stock lowered" do
    sign_in_and_visit_shop
    assert_selector "#archive-offer-blue-depths-1 .archive-offer__stock", text: "2 en stock"

    tile.click
    within "dialog#archive-purchase-dialog" do
      assert_selector "h2", text: "ACHETER AUX ARCHIVES"
      assert_selector ".purchase-confirmation__price", text: "500"
      click_on "ACHETER · 500"
      assert_selector "h2", text: /\AVOUS AVEZ ACHETÉ Profondeurs bleues\z/i
      assert_link "VOIR LA CARTE"
    end
    assert_selector "#archive-offer-blue-depths-1 .archive-offer__stock", text: "1 en stock"
    assert_equal 1, Game::Holding.find_by!(player_id: @player.id, card_season_id: @rare.id).quantity

    find("dialog#archive-purchase-dialog .modal__close").click
    assert_no_selector "dialog#archive-purchase-dialog[open]"
    assert_selector "#archive-offer-blue-depths-1 a:focus"
  end

  test "a visitor reads the shop and each tile leads to the card detail" do
    visit market_shop_path(locale: :fr)

    assert_link "Connectez-vous pour acheter aux Archives"
    assert_no_selector ".archive-offer__buy"
    tile.click
    assert_current_path card_season_path(locale: :fr, slug: "blue-depths", number: 1)
  end

  test "a price changed while the confirmation is open is refused and the new price drawn" do
    sign_in_and_visit_shop
    tile.click
    within("dialog#archive-purchase-dialog") { assert_button "ACHETER · 500" }

    open_market!(first_opened_at: 1.day.ago, archive_price_rare: 600)
    within "dialog#archive-purchase-dialog" do
      click_on "ACHETER · 500"
      assert_selector ".purchase-confirmation__refusal", text: "Les montants ont changé"
      assert_button "ACHETER · 600"
    end
    assert_nil Game::Holding.find_by(player_id: @player.id, card_season_id: @rare.id)
  end
end

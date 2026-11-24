require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/market"
require_relative "../support/market_auctions"

class MarketShopCapSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include MarketAuctions
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @epic = catalog_card_seasons(:portal_one)
    forget_market!
    @settings = open_market!(first_opened_at: 1.day.ago, archive_price_epic: 300, archive_cap_epic: 1, archive_cap_window_days_epic: 7)
    fund!(@player, 1_000)
    Game::Market::ArchiveStock.create!(card_season_id: @epic.id, quantity: 2)
    @withdrawal = Game::Market::ArchiveWithdrawal.create!(player_id: @player.id, card_season_id: @epic.id, purchase_token: SecureRandom.base58(24), price: 300,
      settings_id: @settings.id, created_at: 1.hour.ago)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.setTimezoneOverride", timezoneId: "")
  end

  test "a capped edition's tile names the next purchase, and its confirmation draws no form" do
    page.driver.browser.execute_cdp("Emulation.setTimezoneOverride", timezoneId: "Europe/Paris")
    mock_steam_sign_in(@player.steam_id)
    sign_in_browser(locale: :fr)
    visit market_shop_path(locale: :fr)

    date = I18n.l((@withdrawal.created_at + 7.days).in_time_zone("Europe/Paris"), format: :local_datetime, locale: :fr)
    assert_selector "#archive-offer-portal-1 .archive-offer__cap", text: "1 Épique par semaine · prochaine le #{date}"

    find("#archive-offer-portal-1 a").click
    within "dialog#archive-purchase-dialog" do
      assert_selector ".purchase-confirmation__refusal", text: "Vous avez atteint la limite des Archives pour cette rareté. Prochain achat le #{date}."
      assert_no_selector "form"
      assert_no_button "ACHETER"
    end
  end

  test "buying one copy of a capped rarity rewrites the cap line of the other editions, and their confirmation draws no form" do
    Game::Market::ArchiveWithdrawal.delete_all
    other = Catalog::CardSeason.create!(card_id: @epic.card_id, season: Catalog::Season.create!(number: 2), prestige_score: 0.9, rating: 95.5, rarity: :epic, number: 4)
    Game::Market::ArchiveStock.create!(card_season_id: other.id, quantity: 2)
    mock_steam_sign_in(@player.steam_id)
    sign_in_browser(locale: :fr)
    visit market_shop_path(locale: :fr)
    assert_selector "#archive-offer-portal-1 .archive-offer__cap", text: "Encore 1 Épique par semaine"
    assert_selector "#archive-offer-portal-2 .archive-offer__cap", text: "Encore 1 Épique par semaine"
    assert_selector ".market-shop__rarity-cap", text: "Encore 1 Épique par semaine"

    find("#archive-offer-portal-1 a").click
    within("dialog#archive-purchase-dialog") { click_on "ACHETER · 300" }
    assert_selector "dialog#archive-purchase-dialog .purchase-confirmation__text"
    find("dialog#archive-purchase-dialog .modal__close").click

    assert_selector "#archive-offer-portal-2 .archive-offer__cap", text: /\A1 Épique par semaine · prochaine le/
    assert_selector ".market-shop__rarity-cap", text: /\A1 Épique par semaine · prochaine le/
    find("#archive-offer-portal-2 a").click
    within "dialog#archive-purchase-dialog" do
      assert_selector ".purchase-confirmation__refusal", text: "Vous avez atteint la limite des Archives pour cette rareté."
      assert_no_selector "form"
    end
  end
end

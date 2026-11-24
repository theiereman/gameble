require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/archive_at_reference"

class MarketShopCapSystemTest < ApplicationSystemTestCase
  include ArchiveAtReference
  include SteamSignIn
  include MarketAuctions
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @rare = catalog_card_seasons(:rare_card_one)
    forget_market!
    @settings = open_market!(first_opened_at: 1.day.ago, archive_price_rare: 300)
    fund!(@player, 1_000)
    Game::Market::ArchiveStock.create!(card_season_id: @rare.id, quantity: 2)
    @other = Catalog::CardSeason.create!(card_id: @rare.card_id, season: Catalog::Season.create!(number: 2), prestige_score: 0.9, rating: 95.5, rarity: :rare, number: 4)
    Game::Market::ArchiveStock.create!(card_season_id: @other.id, quantity: 2)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.setTimezoneOverride", timezoneId: "")
  end

  def purchases!(count)
    count.times do
      Game::Market::ArchiveWithdrawal.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:common_card_one).id,
        purchase_token: SecureRandom.base58(24), price: 50, settings_id: @settings.id, created_at: Time.current)
    end
  end

  def sign_in_and_visit_shop
    mock_steam_sign_in(@player.steam_id)
    sign_in_browser(locale: :fr)
    visit market_shop_path(locale: :fr)
  end

  test "after a week's purchases a tile names the next Monday, and its confirmation draws no form" do
    page.driver.browser.execute_cdp("Emulation.setTimezoneOverride", timezoneId: "Europe/Paris")
    purchases!(5)
    sign_in_and_visit_shop

    date = I18n.l((Time.current.utc.beginning_of_week + 1.week).in_time_zone("Europe/Paris"), format: :local_datetime, locale: :fr)
    assert_selector "#archive-offer-blue-depths-1 .archive-offer__cap", text: "5 achats aux Archives par semaine · prochain le #{date}"

    find("#archive-offer-blue-depths-1 a").click
    within "dialog#archive-purchase-dialog" do
      assert_selector ".purchase-confirmation__refusal", text: "Vous avez fait vos 5 achats de la semaine aux Archives. Prochain achat le #{date}."
      assert_no_selector "form"
      assert_no_button "ACHETER"
    end
  end

  test "the fifth purchase of the week writes the limit line on the other editions, and their confirmation draws no form" do
    purchases!(4)
    sign_in_and_visit_shop
    assert_no_selector ".archive-offer__cap"

    find("#archive-offer-blue-depths-1 a").click
    within("dialog#archive-purchase-dialog") { click_on "ACHETER · 300" }
    assert_selector "dialog#archive-purchase-dialog .purchase-confirmation__text"
    find("dialog#archive-purchase-dialog .modal__close").click

    assert_selector "#archive-offer-blue-depths-2 .archive-offer__cap", text: /\A5 achats aux Archives par semaine · prochain le/
    find("#archive-offer-blue-depths-2 a").click
    within "dialog#archive-purchase-dialog" do
      assert_selector ".purchase-confirmation__refusal", text: "Vous avez fait vos 5 achats de la semaine aux Archives."
      assert_no_selector "form"
    end
  end
end

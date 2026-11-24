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
    Game::Market::ArchiveWithdrawal.create!(player_id: @player.id, card_season_id: @epic.id, purchase_token: SecureRandom.base58(24), price: 300,
      settings_id: @settings.id, created_at: 1.hour.ago)
  end

  test "a capped edition's tile names the next purchase, and its confirmation draws no form" do
    mock_steam_sign_in(@player.steam_id)
    visit home_path(locale: :fr)
    click_steam_sign_in
    assert_signed_in
    visit market_shop_path(locale: :fr)

    date = I18n.l((1.hour.ago + 7.days).to_date, format: :day_month, locale: :fr)
    assert_selector "#archive-offer-portal-1 .archive-offer__cap", text: "1 Épique par semaine · prochaine le #{date}"

    find("#archive-offer-portal-1 a").click
    within "dialog#archive-purchase-dialog" do
      assert_selector ".purchase-confirmation__refusal", text: "Vous avez atteint la limite des Archives pour cette rareté. Prochain achat le #{date}."
      assert_no_selector "form"
      assert_no_button "ACHETER"
    end
  end
end

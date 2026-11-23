require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/market"
require_relative "../../support/market_auctions"
require_relative "../../support/counting_rate_limit"

class Market::ArchivePurchasesControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include MarketAuctions
  include MarketSettings
  include SteamSignIn

  STREAM = "text/vnd.turbo-stream.html, text/html".freeze

  setup do
    @player = accounts_players(:player)
    @rare = catalog_card_seasons(:rare_card_one)
    @settings = open_market!(first_opened_at: 1.day.ago, archive_price_rare: 500)
    fund!(@player, 1_000)
    @stock = Game::Market::ArchiveStock.create!(card_season_id: @rare.id, quantity: 2)
  end

  def confirmation(locale: :fr) = get new_market_archive_purchase_path(locale:, slug: "blue-depths", number: 1)

  def purchase_token = css_select("input[name=purchase_token]").first&.[]("value")

  def buy(locale: :fr, settings_token: @settings.token, purchase_token: SecureRandom.base58(24))
    post market_archive_purchase_path(locale:, slug: "blue-depths", number: 1), params: { settings_token:, purchase_token: }, headers: { "Accept" => STREAM }
  end

  def frame = css_select("turbo-stream[action=update][target=archive-purchase] template").first

  def copies = Game::Holding.find_by(player_id: @player.id, card_season_id: @rare.id)&.quantity

  test "a visitor is refused the confirmation and the purchase" do
    confirmation
    assert_redirected_to home_path(locale: :fr)

    assert_no_difference(-> { Game::Market::ArchiveWithdrawal.count }) { buy }
  end

  test "the confirmation draws the card, its edition, the price, the balance after and a fresh purchase token" do
    sign_in(@player)

    confirmation
    assert_response :success
    first = purchase_token

    assert_select "turbo-frame#archive-purchase h2#archive-purchase-title", "ACHETER AUX ARCHIVES ?"
    assert_select ".purchase-confirmation__fact", text: /Carte\s+Profondeurs bleues/
    assert_select ".purchase-confirmation__fact", text: /Édition\s+Rare · saison 1/
    assert_select ".purchase-confirmation__price", /500/
    assert_select ".purchase-confirmation__fact", text: /Solde après\s+500/
    assert_select ".purchase-confirmation__note", "Prix fixe de la Confrérie. La carte garde sa rareté et sa saison."
    assert_select "input[name=settings_token][value=?]", @settings.token
    assert_select "button[type=submit]", "ACHETER · 500"
    assert_match Game::Market::ArchiveWithdrawal::PURCHASE_TOKEN_FORMAT, first

    confirmation
    assert_not_equal first, purchase_token
  end

  test "an unknown edition is a 404" do
    sign_in(@player)

    get new_market_archive_purchase_path(locale: :en, slug: "no-such-game", number: 1)

    assert_response :not_found
  end

  test "short of PiCoins, the confirmation says by how much and offers CONFIER DES CARTES" do
    open_market!(first_opened_at: 1.day.ago, archive_price_rare: 1_200)
    sign_in(@player)

    confirmation

    assert_select "h2.modal__title--alert", "IL VOUS MANQUE 200 PICOINS"
    assert_select ".purchase-confirmation__missing", /\AProfondeurs bleues Rare coûte 1.200, vous avez 1.000\.\z/
    assert_select "a.button--primary[href=?][data-turbo-frame=_top]", new_market_entrustment_path(locale: :fr), text: "CONFIER DES CARTES"
    assert_select ".purchase-confirmation form", 0
    assert_select ".purchase-confirmation__fact", text: /Solde après\s+—\s*aucun/
  end

  test "a closed market draws the confirmation without its form, saying why" do
    close_market!(first_opened_at: 1.day.ago, archive_price_rare: 500)
    sign_in(@player)

    confirmation

    assert_response :success
    assert_select ".purchase-confirmation form", 0
    assert_select ".purchase-confirmation__refusal", "Le marché est suspendu pour le moment."
  end

  test "an edition gone from the stock draws the confirmation without its form, saying why" do
    @stock.delete
    sign_in(@player)

    confirmation

    assert_response :success
    assert_select ".purchase-confirmation form", 0
    assert_select ".purchase-confirmation__refusal", "Cette carte n'est plus disponible. Un autre joueur vient de prendre le dernier exemplaire. Rien n'est débité."
  end

  test "a purchase answers the result in the frame and the tile with its stock lowered" do
    sign_in(@player)

    buy

    assert_response :success
    assert_includes frame.inner_html, "VOUS AVEZ ACHETÉ Profondeurs bleues"
    assert_includes frame.inner_html, card_season_path(locale: :fr, slug: "blue-depths", number: 1)
    assert_select "turbo-stream[action=replace][target=archive-offer-blue-depths-1] template .archive-offer__stock", "1 en stock"
    assert_equal 1, copies
    assert_equal 1, @stock.reload.quantity
  end

  test "the last copy bought removes its tile" do
    @stock.update!(quantity: 1)
    sign_in(@player)

    buy

    assert_select "turbo-stream[action=remove][target=archive-offer-blue-depths-1]"
  end

  test "a copy taken meanwhile is refused, nothing charged, and the confirmation says so" do
    sign_in(@player)
    @stock.delete

    assert_no_difference(-> { Game::Market::LedgerEntry.count }) { buy }

    assert_response :unprocessable_content
    assert_includes frame.inner_html, "Cette carte n'est plus disponible. Un autre joueur vient de prendre le dernier exemplaire. Rien n'est débité."
    assert_select "turbo-stream[action=remove][target=archive-offer-blue-depths-1]"
  end

  test "a price changed meanwhile is refused and the new price drawn with a fresh token" do
    sign_in(@player)
    newer = open_market!(first_opened_at: 1.day.ago, archive_price_rare: 600)

    assert_no_difference(-> { Game::Market::ArchiveWithdrawal.count }) { buy(locale: :en) }

    assert_response :unprocessable_content
    html = Nokogiri::HTML.fragment(frame.inner_html)
    assert_includes html.css(".purchase-confirmation__refusal").text, "The amounts changed while you were choosing."
    assert_equal newer.token, html.at_css("input[name=settings_token]")["value"]
    assert_match Game::Market::ArchiveWithdrawal::PURCHASE_TOKEN_FORMAT, html.at_css("input[name=purchase_token]")["value"]
    assert_equal "BUY · 600", html.at_css("button[type=submit]").text.strip
  end

  test "the eleventh post of a minute is throttled" do
    sign_in(@player)

    with_counting_rate_limit(Market::ArchivePurchasesController) { 11.times { buy(purchase_token: "bad") } }

    assert_redirected_to new_market_archive_purchase_path(locale: :fr, slug: "blue-depths", number: 1)
  end
end

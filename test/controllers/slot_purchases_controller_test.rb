require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/game_sets"
require_relative "../support/custom_sets"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/counting_rate_limit"

# The slot purchase confirmation and the purchase: the next goal, custom set or deck slot at its price; bought, the goal
# control redraws with the goal, or the custom set editor or the new deck's editor opens.
class SlotPurchasesControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include CustomSets
  include GameSets
  include MarketAuctions
  include MarketSettings
  include SteamSignIn

  STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html" }.freeze

  setup do
    @player = accounts_players(:player)
    @settings = open_market!(first_opened_at: 1.day.ago)
    fund!(@player, 1_000)
  end

  def theme(key) = insert_set(unheld_cards(3), { complete: 3 }, key:, params: { "theme" => key })

  def five_goals
    %w[a1 a2 a3 a4 a5 a6].each { theme(it) }
    %w[a1 a2 a3 a4 a5].each { Game::AddGoal.new.call(player: @player, kind: "theme", key: it).value! }
  end

  def aim = { kind: "theme", key: "a6" }

  def confirmation(capacity: "goals", slot: 6, locale: :fr, **params) = get new_slot_purchase_path(locale:, capacity:, slot:, **params)

  def buy(capacity: "goals", slot: 6, locale: :fr, settings_token: @settings.token, headers: STREAM, **params)
    post slot_purchase_path(locale:, capacity:, slot:), params: { settings_token:, **params }, headers:
  end

  def frame = Nokogiri::HTML5.fragment(css_select("turbo-stream[action=update][target=slot-purchase] template").sole.inner_html)

  def bought(kind) = Game::CapacitySlot.where(player_id: @player.id, kind:).pick(:bought)

  test "a visitor is refused the confirmation and the purchase" do
    confirmation(**aim)
    assert_redirected_to home_path(locale: :fr)

    assert_no_difference(-> { Game::CapacitySlot.count }) { buy(capacity: "decks", slot: 4) }
  end

  test "the goal confirmation draws the slot's title, the free count, the price, the balance after and the aim" do
    five_goals
    sign_in(@player)

    confirmation(**aim)

    assert_response :success
    assert_select "turbo-frame#slot-purchase[target=_top] h2#slot-purchase-title" do
      assert_select "span[aria-hidden=true]", "UN 6E OBJECTIF ?"
      assert_select "span.visually-hidden", "Un sixième objectif ?"
    end
    assert_select ".purchase-confirmation__lead",
      "Les 5 premiers objectifs sont gratuits. Un emplacement de plus, gardé pour toujours, et A6 devient votre objectif 6."
    assert_select ".purchase-confirmation__price", /500/
    assert_select ".purchase-confirmation__fact", text: /Solde après\s+500/
    assert_select "form[action='/fr/slots/goals/6'] input[name=settings_token][value=?]", @settings.token
    assert_select "form input[name=kind][value=theme] + input[name=key][value=a6]"
    assert_select "button[type=submit]", "ACHETER · 500"
    assert_no_match(/\b#{@player.id}\b|style=/, response.body.scan(/<turbo-frame.*<\/turbo-frame>/m).sole)
  end

  test "English titles name the slot with its ordinal and article" do
    Game::CapacitySlot.create!(player_id: @player.id, kind: "custom_set", bought: 2)
    sign_in(@player)

    confirmation(capacity: "custom-sets", slot: 8, locale: :en)
    assert_select "#slot-purchase-title span[aria-hidden=true]", "AN 8TH SET?"
    assert_select "#slot-purchase-title .visually-hidden", "An eighth set?"

    confirmation(capacity: "decks", slot: 4, locale: :en)
    assert_select "#slot-purchase-title span[aria-hidden=true]", "A 4TH DECK?"
    assert_select ".purchase-confirmation__lead", "The first 3 decks are free. One more slot, kept for good, then the new deck opens."
  end

  test "an unknown aim, a slot outside the priced ones or no settings version is not found" do
    sign_in(@player)

    confirmation(kind: "theme", key: "pirates")
    assert_response :not_found
    confirmation(capacity: "decks", slot: 3)
    assert_response :not_found
    confirmation(capacity: "decks", slot: 6)
    assert_response :not_found
    forget_market!
    confirmation(capacity: "decks", slot: 4)
    assert_response :not_found
  end

  test "a slot beyond the next one is not found, on the confirmation and on a refused purchase" do
    sign_in(@player)

    confirmation(capacity: "decks", slot: 5)
    assert_response :not_found

    assert_no_difference(-> { Game::CapacitySlot.count }) { buy(capacity: "decks", slot: 5) }
    assert_response :not_found
  end

  test "short of PiCoins, the confirmation says by how much, with CONFIER DES CARTES while the market is open only" do
    open_market!(first_opened_at: 1.day.ago, slot_price_deck_4: 1_200)
    sign_in(@player)

    confirmation(capacity: "decks", slot: 4)

    assert_select ".purchase-confirmation__missing", "Il vous manque 200 PiCoins."
    assert_select ".purchase-confirmation__fact", text: /Solde après\s+—\s*aucun/
    assert_select ".purchase-confirmation form", 0
    assert_select "a.button", "CONFIER DES CARTES"

    close_market!(slot_price_deck_4: 1_200)
    confirmation(capacity: "decks", slot: 4)

    assert_select ".purchase-confirmation__missing", "Il vous manque 200 PiCoins."
    assert_select ".purchase-confirmation a.button", 0
    assert_select ".market-dialog__actions button", "ANNULER"
  end

  test "a slot bought meanwhile is drawn closed, with the line that says so" do
    Game::CapacitySlot.create!(player_id: @player.id, kind: "deck", bought: 1)
    sign_in(@player)

    confirmation(capacity: "decks", slot: 4)

    assert_select ".purchase-confirmation__refusal", "Cet emplacement est déjà acheté."
    assert_select ".purchase-confirmation form", 0

    assert_no_difference(-> { Game::Market::LedgerEntry.count }) { buy(capacity: "decks", slot: 4) }
    assert_response :unprocessable_content
    assert_equal "Cet emplacement est déjà acheté.", frame.at_css(".purchase-confirmation__refusal").text
  end

  test "a price changed meanwhile is refused and the new price drawn with the settings line" do
    sign_in(@player)
    newer = open_market!(first_opened_at: 1.day.ago, slot_price_deck_4: 900)

    assert_no_difference(-> { Game::CapacitySlot.count }) { buy(capacity: "decks", slot: 4, locale: :en) }

    assert_response :unprocessable_content
    assert_includes frame.at_css(".purchase-confirmation__refusal").text, "The amounts changed while you were choosing."
    assert_equal newer.token, frame.at_css("input[name=settings_token]")["value"]
    assert_equal "BUY · 900", frame.at_css("button[type=submit]").text.strip
  end

  test "a goal slot bought redraws the control with goal 6 and the bought line, by morph" do
    five_goals
    sign_in(@player)

    buy(**aim)

    assert_response :ok
    assert_equal 1, bought("goal")
    assert_select "turbo-stream[action=replace][target=set-album-goal][method=morph]"
    control = Nokogiri::HTML5.fragment(css_select("turbo-stream template").sole.inner_html)
    assert_equal "6Objectif 6 · Retirer", control.at_css("#set-album-goal.goal-control--set[data-goal-control-bought-value=true] button.goal-button").text.squish
    status = control.at_css("p.goal-control__refusal--bought[role=status]")
    assert_equal "6E OBJECTIF ACHETÉ", status.at_css("[aria-hidden=true]").text
    assert_equal "Sixième objectif acheté", status.at_css(".visually-hidden").text
    assert_includes status.text, "A6 est votre objectif 6."
    assert_nil control.at_css("dialog")
  end

  test "a goal slot bought without Turbo returns to the album with the bought line" do
    five_goals
    sign_in(@player)

    buy(headers: {}, **aim)

    assert_redirected_to "/fr/library/theme/a6"
    assert_equal "Sixième objectif acheté · A6 est votre objectif 6.", flash[:notice]
  end

  test "a custom set slot bought opens the editor on the Collection" do
    5.times { create_custom_set(@player, name: "Set #{it}") }
    sign_in(@player)

    assert_no_difference(-> { Game::CustomSet.count }) { buy(capacity: "custom-sets") }

    assert_redirected_to "/fr/library"
    follow_redirect!
    assert_select "dialog#custom-set-editor[open] input#custom-set-name[autofocus]"
  end

  test "a deck slot bought opens the new deck's editor with its name field focused" do
    3.times { |index| Game::CreateDeck.new.call(player: @player, name: "Deck #{index}").value! }
    sign_in(@player)

    assert_no_difference(-> { Game::Deck.count }) { buy(capacity: "decks", slot: 4) }

    assert_redirected_to "/fr/duels/decks/new"
    follow_redirect!
    assert_select "input#deck-name[autofocus]"
  end

  test "the eleventh post of a minute is throttled" do
    sign_in(@player)

    with_counting_rate_limit(SlotPurchasesController) { 11.times { buy(capacity: "decks", slot: 4, settings_token: "bad") } }

    assert_redirected_to new_slot_purchase_path(locale: :fr, capacity: "decks", slot: 4)
  end
end

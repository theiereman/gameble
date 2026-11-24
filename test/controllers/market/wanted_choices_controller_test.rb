require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/holdings"
require_relative "../../support/market"
require_relative "../../support/market_auctions"
require_relative "../../support/market_orders"
require_relative "../../support/counting_rate_limit"

class Market::WantedChoicesControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include Holdings
  include MarketSettings
  include MarketAuctions
  include MarketOrders
  include CountingRateLimit

  STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  setup do
    Game::Market::Settings.delete_all
    @settings = open_market!(first_opened_at: 1.day.ago)
    @player = accounts_players(:player)
    @buyer = accounts_players(:moderator)
    @seeker = accounts_players(:administrator)
    @rare = catalog_card_seasons(:rare_card_one)
    @common = catalog_card_seasons(:common_card_one)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
    fund!(@buyer, 5_000)
    @order = order!(@buyer, @uncommon, 900)
    Game::Market::RebuildWanted.new.call(player: @buyer).value!
    Game::Market::Wanted.insert_all([ { player_id: @seeker.id, card_id: @common.card_id, reason: "goal", rarities: nil },
      { player_id: @seeker.id, card_id: @rare.card_id, reason: "goal", rarities: nil } ])
    hold(@player, @uncommon.id, 1)
    hold(@player, @common.id, 1)
    hold(@player, @rare.id, 1)
  end

  def ref(card_season) = "#{card_season.card.slug}:#{card_season.season.number}"

  def selection(*cards) = cards.map { "#{ref(it)}=1" }.join(",")

  def deposited(card) = Game::Market::ArchiveDeposit.find_by(player_id: @player.id, card_season_id: card.id)&.quantity.to_i

  def line(card, choice, orders: [], price: nil, hours: nil)
    { ref: ref(card), copies: 1, choice:, orders:, starting_price: price, duration_hours: hours }.compact
  end

  def validate(lines, selected: [ @uncommon, @common, @rare ], headers: STREAM, **params)
    post market_wanted_choices_path(locale: :fr), headers:,
      params: { settings: @settings.token, selection: selection(*selected), lines: lines.each_with_index.to_h { |each, index| [ index.to_s, each ] }, **params }
  end

  def nothing_moves(&)
    assert_no_difference([ -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.sum(:quantity) }, -> { Game::Market::Listing.count },
      -> { Game::Market::ArchiveDeposit.sum(:quantity) } ], &)
  end

  test "a visitor is sent home from the step and its validation" do
    get new_market_wanted_choice_path(locale: :fr, selection: selection(@uncommon))
    assert_redirected_to home_path(locale: :fr)

    post market_wanted_choices_path(locale: :fr), params: { selection: selection(@uncommon) }
    assert_redirected_to home_path(locale: :fr)
  end

  test "the eleventh validation of a minute is throttled back to the step" do
    sign_in(@player)

    with_counting_rate_limit(Market::WantedChoicesController) do
      11.times { post market_wanted_choices_path(locale: :fr), params: { settings: "stale", selection: selection(@uncommon) } }
    end

    assert_redirected_to new_market_wanted_choice_path(locale: :fr, selection: selection(@uncommon))
  end

  test "a step with nothing still set apart leads to the market" do
    sign_in(@player)

    get new_market_wanted_choice_path(locale: :fr, selection: "unknown:1=1")

    assert_redirected_to market_path(locale: :fr)
  end

  test "a refusal whose table is gone meanwhile leads to the market with the refusal" do
    sign_in(@player)
    Game::Holding.where(player_id: @player.id).update_all("reserved = quantity")

    nothing_moves { validate([ line(@uncommon, "entrust") ], selected: [ @uncommon ]) }

    assert_redirected_to market_path(locale: :fr)
    assert_equal "Certains choix sont à corriger. Rien n'a été vendu, mis en vente ni confié.", flash[:alert]
  end

  test "the table draws each line, best order first, with tokens and no database id, and a GET writes nothing" do
    Game::Market::EditionPrice.create!(card_season_id: @uncommon.id, average: 1_000, sales_used: 5)
    sign_in(@player)

    assert_no_difference [ -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.sum(:quantity) } ] do
      get new_market_wanted_choice_path(locale: :fr, selection: selection(@common, @uncommon, @rare))
    end

    assert_response :success
    assert_select "form#wanted-table[data-controller=wanted-table][data-wanted-table-focus-value=market-wanted-heading]"
    assert_select "#market-wanted-heading[tabindex='-1']", /3 cartes que d'autres joueurs veulent/
    assert_equal [ ref(@uncommon), ref(@rare), ref(@common) ], css_select(".wanted-line").map { it["data-ref"] }
    assert_select "#wanted-line-0[data-orders='900'][data-direct=true][data-average='1000'][data-value='20'][data-changed=false][data-title=?]", "Collines vertes"
    assert_select "input[name='lines[0][orders][]'][value=?]", @order.token
    assert_select "input[name='lines[0][ref]'][value=?]", ref(@uncommon)
    assert_select "#wanted-line-0-choice[role=radiogroup][aria-label=?]", "Collines vertes, peu commune, saison 1 : votre choix"
    assert_select "#wanted-line-0-choice input[value=order]:not([disabled])[aria-label=?]", "À l'ordre, 900 PiCoins"
    assert_select "#wanted-line-2-choice[aria-describedby=wanted-line-2-no-order] input[value=order][disabled]"
    assert_select "#wanted-line-2-no-order", "Aucun ordre"
    assert_select "#wanted-line-1[data-direct=false][data-orders='']"
    assert_select "#wanted-line-1-choice input[value=order]", false
    assert_select "#wanted-line-1-choice input", 2
    assert_select "#wanted-line-1-choice[aria-describedby=wanted-line-1-backed-note]"
    assert_select "#wanted-line-1-backed-note", "Une Rare ou plus se vend aux enchères, que les ordres d'achat soutiennent."
    assert_select "input[name='lines[1][orders][]']", false
    assert_select "#wanted-line-0-choice input[checked]", false
    assert_select ".wanted-auction[hidden] input[disabled]", minimum: 1
    assert_select "button[type=submit]", "VALIDER LES 3 CHOIX"
    assert_select "button[type=submit][name=all][value='1'][aria-describedby=wanted-not-returned]"
    assert_select "[style]", false
    assert_no_match(/lines\[\d\]\[card_season_id\]|value="#{@uncommon.id}"/, response.body)
  end

  test "an order, an auction and an entrustment apply together and the result names each" do
    fund!(@player, 100)
    sign_in(@player)

    validate([ line(@uncommon, "order", orders: [ @order.token ]), line(@rare, "auction", price: "100", hours: "24"), line(@common, "entrust") ])

    assert_response :success
    listing = Game::Market::Listing.find_by!(seller: @player)
    assert_equal [ "served", 1 ], [ @order.reload.status, deposited(@common) ]
    assert_select "turbo-stream[action=replace][target=market-wanted-choices-region]"
    assert_select "turbo-stream[action=gameble-focus][target=wanted-result-heading]"
    assert_select "#wanted-result-heading", "VOS 3 CHOIX SONT APPLIQUÉS"
    assert_select ".wanted-result__line--sold .market-row__chip", "VENDUE"
    assert_select ".wanted-result__line--listed .market-row__chip", "EN COURS"
    assert_select ".wanted-result__line--listed a[href=?]", market_listing_path(locale: :fr, token: listing.token), text: "VOIR L'ANNONCE"
    assert_select ".wanted-result__line--entrusted .market-row__chip", "CONFIÉE"
    assert_select ".wanted-result__back a[href=?]", market_path(locale: :fr), text: "RETOUR AU MARCHÉ"
  end

  test "an order served meanwhile refuses the table, flags its line and keeps every typed price" do
    sign_in(@player)
    @order.update_columns(status: "withdrawn")

    nothing_moves do
      validate([ line(@uncommon, "order", orders: [ @order.token ]), line(@rare, "auction", price: "1 234", hours: "24"), line(@common, "entrust") ])
    end

    assert_response :unprocessable_content
    assert_select ".wanted-line--changed[data-ref=?][data-changed=true]", ref(@uncommon)
    assert_select "#wanted-line-1-changed", /aucun autre n'atteint cette carte/
    assert_select "#wanted-line-1-choice[aria-describedby='wanted-dock-refusal wanted-line-1-changed wanted-line-1-no-order']"
    assert_select "#wanted-line-1-choice input[checked]", false
    assert_match(/\A1.234\z/, css_select("input#wanted-line-0-start").sole["value"])
    assert_select "#wanted-line-0-choice input[value=auction][checked]"
    assert_select "#wanted-dock-refusal", "1 ligne a changé : Collines vertes. Rien n'a été vendu, mis en vente ni confié."
    assert_select "form[data-wanted-table-focus-value=wanted-line-1-choice]"
  end

  test "a better order placed meanwhile names it in the changed line" do
    sign_in(@player)
    fund!(@seeker, 2_000)
    order!(@seeker, @uncommon, 1_000)

    validate([ line(@uncommon, "order", orders: [ @order.token ]) ], selected: [ @uncommon ])

    assert_response :unprocessable_content
    assert_select "#wanted-line-0-changed", /Un meilleur ordre vient d'arriver.{3}1.000 PiCoins\. Vérifiez-le/
  end

  test "fields refused on submit are named under each field and counted in the dock" do
    sign_in(@player)

    nothing_moves do
      validate([ line(@uncommon, "auction", price: "10", hours: "24"), line(@rare, "auction", price: "100", hours: "24") ], selected: [ @uncommon, @rare ])
    end

    assert_response :unprocessable_content
    assert_select "input#wanted-line-0-start[aria-invalid=true][aria-describedby='wanted-line-0-hint wanted-line-0-start-error']"
    assert_select "#wanted-line-0-start-error", "Au moins 34 pour une peu commune."
    short = @settings.stamp(:rare) + @settings.stamp(:uncommon)
    assert_select "#wanted-dock-refusal", "1 prix à corriger. Il vous manque #{short} PiCoins pour les timbres des enchères."
    assert_select "form[data-wanted-table-focus-value=wanted-line-0-start]"
  end

  test "a refused line the table no longer draws is neither flagged nor counted" do
    sign_in(@player)

    nothing_moves do
      validate([ line(@uncommon, "entrust"), line(@common, "auction", price: "abc", hours: "24") ], selected: [ @uncommon ])
    end

    assert_response :unprocessable_content
    assert_select ".wanted-line", 1
    assert_select ".wanted-line__refusal, .wanted-auction [aria-invalid=true]", false
    assert_select "#wanted-dock-refusal", "Certains choix sont à corriger. Rien n'a été vendu, mis en vente ni confié."
  end

  test "an order served meanwhile on a line the table no longer draws flags no line" do
    sign_in(@player)
    @order.update_columns(status: "withdrawn")

    nothing_moves do
      validate([ line(@uncommon, "order", orders: [ @order.token ]), line(@common, "entrust") ], selected: [ @common ])
    end

    assert_response :unprocessable_content
    assert_select ".wanted-line--changed", false
    assert_select "#wanted-dock-refusal", "Cet ordre d'achat vient d'être servi. Vérifiez le nouveau meilleur ordre, puis validez de nouveau."
  end

  test "a posted order choice on a line with no order is redrawn unchosen" do
    sign_in(@player)

    nothing_moves do
      validate([ line(@rare, "auction", price: "abc", hours: "24"), line(@common, "order") ], selected: [ @common, @rare ])
    end

    assert_response :unprocessable_content
    assert_select ".wanted-line[data-ref='#{ref(@common)}'] [id$='-choice'] input[value=order][disabled]"
    assert_select ".wanted-line[data-ref='#{ref(@common)}'] [id$='-choice'] input[checked]", false
    assert_select ".wanted-line[data-ref='#{ref(@rare)}'] [id$='-choice'] input[value=auction][checked]"
  end

  test "a stale settings version redraws the table and keeps the choices" do
    sign_in(@player)

    nothing_moves do
      validate([ line(@uncommon, "entrust") ], selected: [ @uncommon ], settings: "stale")
    end

    assert_response :unprocessable_content
    assert_select "#wanted-dock-refusal", /Les montants ont changé/
    assert_select "#wanted-line-0-choice input[value=entrust][checked]"
  end

  test "a Rare line shows its best order, hands its script the prices that would back an auction and posts no order token" do
    fund!(@seeker, 2_000)
    first = order!(@seeker, @rare, 1_000)
    sign_in(@player)

    get new_market_wanted_choice_path(locale: :fr, selection: selection(@rare))

    assert_response :success
    assert_select "#wanted-line-0[data-direct=false][data-orders='1000']"
    assert_select "#wanted-line-0 .wanted-line__figure .picoin-amount__figure", /1.000/
    assert_select "#wanted-line-0-no-order", false
    assert_select "#wanted-line-0-choice input[value=order]", false
    assert_select "input[name='lines[0][orders][]']", false
    assert_no_match(/#{first.token}/, response.body)
  end

  test "an order choice on a Rare is refused with its line named and nothing moves" do
    fund!(@seeker, 2_000)
    rare_order = order!(@seeker, @rare, 1_000)
    sign_in(@player)

    nothing_moves { validate([ line(@rare, "order", orders: [ rare_order.token ]) ], selected: [ @rare ]) }

    assert_response :unprocessable_content
    assert_select ".wanted-line[data-ref=?] .wanted-line__refusal", ref(@rare), "Une Rare ou plus se vend aux enchères, que les ordres d'achat soutiennent."
    assert_equal "open", rare_order.reload.status
  end

  test "an auction at or below an order converts it and its result line says it is led by the order" do
    fund!(@seeker, 2_000)
    rare_order = order!(@seeker, @rare, 1_000)
    fund!(@player, 100)
    sign_in(@player)

    validate([ line(@rare, "auction", price: "800", hours: "24") ], selected: [ @rare ])

    assert_response :success
    assert_equal [ "bid", @seeker.id ], [ rare_order.reload.status, Game::Market::Listing.find_by!(seller: @player).leader_id ]
    assert_select ".wanted-result__line--listed", /\(menée par un ordre d'achat à\s+800/
  end

  test "entrusting all anyway entrusts every set-apart copy and shows Confier's result" do
    sign_in(@player)

    validate([ line(@uncommon, "order", orders: [ @order.token ]), line(@common, "auction") ], selected: [ @uncommon, @common ], all: "1")

    assert_response :success
    assert_equal [ 1, 1, "open" ], [ deposited(@uncommon), deposited(@common), @order.reload.status ]
    assert_select "#entrust-result-heading"
    assert_select "turbo-stream[action=gameble-focus][target=entrust-result-heading]"
    assert_select ".wanted-result__back a[href=?]", market_path(locale: :fr)
  end

  test "a copy over the cap at validation is skipped and named while the rest applies" do
    @settings = open_market!(first_opened_at: 1.day.ago, daily_cap: @settings.entrustment(:common))
    sign_in(@player)

    validate([ line(@uncommon, "order", orders: [ @order.token ]), line(@rare, "entrust"), line(@common, "entrust") ])

    assert_response :success
    assert_equal [ 0, 1 ], [ deposited(@rare), deposited(@common) ]
    assert_select "#wanted-result-heading", "2 CHOIX SUR 3 APPLIQUÉS"
    assert_select ".wanted-result .entrust-result__stayed-line", /saison 1.{3}1 exemplaire reste dans votre collection/
  end

  test "a line the cap lets only part of through counts as applied" do
    @settings = open_market!(first_opened_at: 1.day.ago, daily_cap: @settings.entrustment(:common))
    Game::Holding.where(player_id: @player.id, card_season_id: @common.id).update_all(quantity: 2)
    sign_in(@player)

    validate([ line(@uncommon, "order", orders: [ @order.token ]), line(@common, "entrust").merge(copies: 2) ], selected: [ @uncommon, @common ])

    assert_response :success
    assert_equal 1, deposited(@common)
    assert_select "#wanted-result-heading", "VOS 2 CHOIX SONT APPLIQUÉS"
    assert_select ".wanted-result .entrust-result__stayed-line", /saison 1.{3}1 exemplaire reste dans votre collection/
  end
end

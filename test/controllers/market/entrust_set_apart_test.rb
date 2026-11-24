require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/holdings"
require_relative "../../support/market"

class Market::EntrustSetApartTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include Holdings
  include MarketSettings

  setup do
    Game::Market::Settings.delete_all
    @settings = open_market!
    @player = accounts_players(:player)
    @seeker = accounts_players(:moderator)
    @rare = catalog_card_seasons(:rare_card_one)
    @common = catalog_card_seasons(:common_card_one)
    Game::Market::Wanted.insert_all([ { player_id: @seeker.id, card_id: @rare.card_id, reason: "goal", rarities: nil } ])
    sign_in(@player)
  end

  def ref(card_season) = "#{card_season.card.slug}:#{card_season.season.number}"

  def selection(ticks) = ticks.map { |ref, copies| "#{ref}=#{copies}" }.join(",")

  def deposited(card) = Game::Market::ArchiveDeposit.find_by(player_id: @player.id, card_season_id: card.id)&.quantity.to_i

  def entrust(ticks) = post market_entrustments_path(locale: :fr), params: { settings: @settings.token, selection: selection(ticks) }

  test "a wanted cell carries its badge, its spoken seekers and its seekers for the recap" do
    hold(@player, @rare.id, 2)
    hold(@player, @common.id, 1)

    get new_market_entrustment_path(locale: :fr, filter: { query: "" })

    assert_select ".entrust-cell[data-ref=?][data-seekers=1] .entrust-cell__wanted[aria-hidden=true]", ref(@rare), text: "DEMANDÉE · 1"
    assert_match "demandée par 1 joueur", css_select(".entrust-cell[data-ref='#{ref(@rare)}'] .entrust-cell__toggle").sole["aria-label"]
    assert_select ".entrust-cell[data-ref='#{ref(@common)}'][data-seekers='0']"
    assert_select ".entrust-cell[data-ref='#{ref(@common)}'] .entrust-cell__wanted", false
    assert_select ".entrust-grid__step[hidden]", "Étape 1 sur 2"
  end

  test "the selection of every match carries each edition's seekers" do
    hold(@player, @rare.id, 2)
    hold(@player, @common.id, 2)

    get market_entrustment_matches_path(locale: :fr), as: :json

    assert_equal({ ref(@rare) => 1, ref(@common) => 0 }, response.parsed_body.to_h { [ it["ref"], it["seekers"] ] })
  end

  test "wanted and other copies: the rest is entrusted and the wanted copy set apart in the next step's address" do
    hold(@player, @rare.id, 2)
    hold(@player, @common.id, 3)

    entrust(ref(@rare) => 2, ref(@common) => 3)

    assert_redirected_to new_market_wanted_choice_path(locale: :fr, selection: "#{ref(@rare)}=1")
    assert_equal [ 1, 3 ], [ deposited(@rare), deposited(@common) ]
    follow_redirect!
    assert_select ".wanted-strip__step", "Étape 2 sur 2"
    assert_select ".wanted-strip__first", "Les 4 autres exemplaires sont déjà confiés : 80 PiCoins fabriqués."
    assert_select ".wanted-line[data-ref=?][data-copies=1]", ref(@rare)
  end

  test "only wanted copies ticked: nothing is entrusted and the table opens" do
    hold(@player, @rare.id, 1)

    assert_no_difference -> { Game::Market::LedgerEntry.count } do
      entrust(ref(@rare) => 1)
    end

    assert_redirected_to new_market_wanted_choice_path(locale: :fr, selection: "#{ref(@rare)}=1")
    follow_redirect!
    assert_select ".wanted-strip__first", false
  end

  test "a rest that fits nothing still opens the table, naming the copies left over" do
    open_market!(daily_cap: 5)
    @settings = Game::Market::CurrentSettings.call
    hold(@player, @rare.id, 1)
    hold(@player, @common.id, 2)

    entrust(ref(@rare) => 1, ref(@common) => 2)

    assert_redirected_to new_market_wanted_choice_path(locale: :fr, selection: "#{ref(@rare)}=1")
    assert_equal 0, deposited(@common)
    follow_redirect!
    assert_select ".wanted-strip__first", false
    assert_select ".wanted-strip .entrust-result__stayed-line", /saison 1 : 2 exemplaires restent dans votre collection/
  end

  test "a rest the cap lets only part through names, on the next step, the copies left over" do
    @settings = open_market!(daily_cap: 60)
    hold(@player, @rare.id, 2)
    hold(@player, @common.id, 3)

    entrust(ref(@rare) => 2, ref(@common) => 3)

    assert_equal [ 1, 1 ], [ deposited(@rare), deposited(@common) ]
    follow_redirect!
    assert_select ".wanted-strip__first", "Les 2 autres exemplaires sont déjà confiés : 60 PiCoins fabriqués."
    assert_select ".wanted-strip .entrust-result__stayed-line", /saison 1 : 2 exemplaires restent dans votre collection/
  end

  test "a table gone before it opens leads to the market, saying what the first step entrusted" do
    hold(@player, @rare.id, 2)
    hold(@player, @common.id, 3)

    entrust(ref(@rare) => 2, ref(@common) => 3)
    Game::Holding.where(player_id: @player.id, card_season_id: @rare.id).update_all("reserved = quantity")
    follow_redirect!

    assert_redirected_to market_path(locale: :fr)
    assert_equal "Les 4 autres exemplaires sont déjà confiés : 80 PiCoins fabriqués.", flash[:notice]
  end

  test "a refused rest sets nothing apart and redraws Confier" do
    hold(@player, @rare.id, 1)
    hold(@player, @common.id, 1)

    post market_entrustments_path(locale: :fr), params: { settings: "stale", selection: selection(ref(@rare) => 1, ref(@common) => 1) }

    assert_response :unprocessable_content
    assert_select "#market-entrust-refusal"
    assert_equal 0, deposited(@common)
  end
end

require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

# ENVOYER on a suggestion row: the friend's cards proposed as they stand,
# the title-only toast, and the focus on the row now in its place.
class TradeSuggestionsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include CustomSets
  include GameSets
  include Holdings
  include SteamSignIn

  def sign_in_origin = "/fr"

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    @alice.update!(persona_name: "Hugo")
    @bob.update!(persona_name: "Lea")
    @carol.update!(persona_name: "Max")
    [ @bob, @carol ].each { befriend(@alice, it) }
    @soldier = catalog_card_seasons(:common_card_one).id
    @hills = catalog_card_seasons(:uncommon_card_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    hold(@alice, @soldier)
    goal_on(@soldier, @hills, @depths)
    hold(@bob, @depths, 2)
    hold(@bob, @hills, 2)
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def goal_on(*card_season_ids)
    card_ids = Catalog::CardSeason.where(id: card_season_ids).pluck(:card_id)
    Game::AddGoal.new.call(player: @alice, custom_set: create_custom_set(@alice, name: "Objectif #{Game::Goal.count + 1}", card_ids:).token).value!
  end

  def send_suggestion(friend: @bob, take: { "blue-depths--s1" => 1, "green-hills--s1" => 1 }, position: 0)
    post suggestions_trades_path(locale: :fr), params: { friend: friend.token, take:, position: }
  end

  def items(trade) = trade.items.order(:card_season_id).map { [ it.side, it.card_season_id, it.quantity ] }

  test "a visitor is sent to the landing and nothing is proposed" do
    assert_no_difference -> { Game::Trade.count } do
      send_suggestion
    end

    assert_redirected_to home_path(locale: :fr)
  end

  test "ENVOYER proposes the friend's cards as an open request and leaves a draft stored for the friend alone" do
    sign_in @alice

    assert_difference -> { Game::Trade.count }, 1 do
      send_suggestion
    end

    trade = Game::Trade.last
    assert_equal [ @alice.id, @bob.id, "open" ], [ trade.proposer_id, trade.recipient_id, trade.status ]
    assert_equal [ [ "request", @hills, 1 ], [ "request", @depths, 1 ] ].sort, items(trade).sort
    assert_equal 0, Game::Holding.where(player_id: @bob.id).sum(:reserved)
    assert_response :see_other
    assert_redirected_to trades_path(locale: :fr)
    assert_nil flash[:trade_forget]
    assert_equal "Proposition transmise", flash[:title_toast]

    follow_redirect!

    assert_select "#toasts > .toast", 1 do
      assert_select ".toast__title", "Proposition transmise"
      assert_select ".toast__message", 0
    end
    assert_select ".trade-suggestions", 0
    assert_select ".trade-row[href=?][autofocus]", trade_path(locale: :fr, token: trade.token)
    assert_select "[data-trade-board-forget-value]:not([data-trade-board-forget-value=''])", 0
  end

  test "after ENVOYER the focus lands on the suggestion now in the sent row's place" do
    crown = catalog_card_seasons(:legendary_card_one).id
    goal_on(@soldier, crown, catalog_card_seasons(:portal_one).id)
    hold(@carol, crown, 2)
    sign_in @alice

    get trades_path(locale: :fr)
    assert_equal [ "LEA", "MAX" ], css_select(".trade-suggestion__name").map { it.text.strip.upcase }

    send_suggestion

    follow_redirect!
    assert_select ".trade-suggestion", 1
    assert_select ".trade-suggestion__opener[autofocus]", 1
    assert_match(/Max/, css_select(".trade-suggestion__opener[autofocus]").sole["aria-label"])
    assert_select ".trade-row[autofocus]", 0
  end

  test "a refused suggestion shows the board's refusal in a toast alone and returns to the list, proposing nothing" do
    Game::ProposeTrade.new.call(player: @carol, recipient: @alice, offer: {}, request: { @soldier => 1 }).value!
    sign_in @alice
    Game::Holding.where(player_id: @bob.id, card_season_id: @hills).delete_all

    assert_no_difference -> { Game::Trade.count } do
      send_suggestion
    end

    assert_redirected_to trades_path(locale: :fr)
    assert flash[:alert].present?
    assert_nil flash[:title_toast]
    assert_nil flash[:trade_error]
    follow_redirect!
    assert_select "#toasts > .toast--alert"
    assert_select ".trade-board"
    assert_select ".trade-board__error", 0

    @bob.update_columns(visibility: "private")
    send_suggestion(take: { "blue-depths--s1" => 1 })

    assert_redirected_to trades_path(locale: :fr)
    assert_equal "Le profil de Lea est privé : échanges fermés.", flash[:alert]

    send_suggestion(friend: accounts_players(:banned))

    assert_redirected_to trades_path(locale: :fr)
    assert_equal I18n.t("errors.game.not_friends", locale: :fr), flash[:alert]
    assert_equal 1, Game::Trade.count
  end

  test "sending suggestions is limited to 20 a minute" do
    sign_in @alice

    with_counting_rate_limit(TradeSuggestionsController) do
      21.times { send_suggestion(take: {}) }
    end

    assert_redirected_to trades_path(locale: :fr)
    assert_equal I18n.t("trades.throttled", locale: :fr), flash[:alert]
  end

  test "a mutual suggestion reads against the player's spare and ENVOYER proposes both sides" do
    portal = catalog_card_seasons(:portal_one).id
    hold(@alice, portal, 2)
    insert_set([ portal, *unheld_cards(2) ], { complete: 3 }, key: "mutual", params: { "theme" => "mutual" })
    Game::AddGoal.new.call(player: @bob, kind: "theme", key: "mutual").value!
    sign_in @alice

    get trades_path(locale: :fr)

    assert_select ".trade-suggestion__summary", text: /\scontre\s/
    assert_select "a.trade-suggestion__opener[href*=?]", "give"

    assert_difference -> { Game::Trade.count }, 1 do
      send_suggestion(take: { "blue-depths--s1" => 1, "green-hills--s1" => 1 }, position: 0)
    end
  end
end

require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"

class CardTradeSheetTest < ActionDispatch::IntegrationTest
  include Holdings
  include SteamSignIn

  APP = "Gameble Android; Hotwire Native Android; Turbo Native Android; bridge-components: [sign-in share haptics]".freeze

  def sign_in_origin = "/en"

  setup do
    @player = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @max = accounts_players(:administrator)
    @player.update!(persona_name: "Hugo")
    @lea.update!(persona_name: "Lea")
    @max.update!(persona_name: "Max")
    @portal = catalog_card_seasons(:portal_one)
    [ @lea, @max ].each { befriend(it) }
  end

  def befriend(friend)
    low, high = [ @player.id, friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def card_path(locale: :en) = card_season_path(slug: catalog_cards(:portal).slug, number: @portal.season.number, locale:)

  def portal_key = "#{catalog_cards(:portal).slug}--s#{@portal.season.number}"

  def opener_for(friend) = new_trade_path(friend: friend.token, ask: portal_key, locale: :en)

  def board_lines = css_select("[data-trade-board-target='line']").map { [ it["data-side"], it["data-key"], it["data-quantity"].to_i ] }

  def ask(friend) = Game::ProposeTrade.new.call(player: @player, recipient: friend, offer: {}, request: { @portal.id => 1 }).value!

  def trade_sides(trade)
    Game::TradeItem.where(trade_id: trade.id).group_by(&:side).transform_values { |items| items.to_h { [ it.card_season_id, it.quantity ] } }
      .reverse_merge("offer" => {}, "request" => {})
  end

  def section_names = css_select(".card-trade-section .card-trade__name").map { it.text.strip }

  def proposals = css_select(".card-trade-section .card-trade__row a.button").map { it["href"] }

  def befriend_new(name)
    Accounts::Player.create!(steam_id: "765611980002#{(Accounts::Player.count + 1).to_s.rjust(5, "0")}", persona_name: name).tap { befriend(it) }
  end

  def portal_edition(number, rarity:)
    season = Catalog::Season.create!(status: :draft, number:)
    season.update!(status: :published, published_at: Time.current)
    Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: season.id, prestige_score: 0.5, rating: 90, rarity:, number: 1 } ],
      returning: :id).rows.flatten.sole
  end

  test "a missing card lists every friend who holds it in its own section, a single copy included, each with a way to propose" do
    hold(@lea, @portal.id, 1)
    hold(@max, @portal.id, 3)
    sign_in @player

    get card_path

    assert_response :success
    assert_select "section.card-trade-section[aria-labelledby=card-trade-heading] h2#card-trade-heading", "Trade for this card"
    assert_equal [ "Max", "Lea" ], section_names
    assert_equal [ opener_for(@max), opener_for(@lea) ], proposals
    assert_select ".card-trade-section .card-trade__copies", text: "3 copies"
    assert_select "#card-trade-sheet", 0
    assert_select ".card-detail__fact--owners", 0
    assert_no_match(/\b#{@lea.id}\b/, css_select(".card-trade-section").to_s)
    assert_select "[style]", 0
  end

  test "past three friends the section shows the first three and opens the rest in a sheet" do
    hold(@lea, @portal.id, 5)
    hold(@max, @portal.id, 4)
    others = [ 3, 2 ].map.with_index { |copies, index| befriend_new("Friend #{index}").tap { hold(it, @portal.id, copies) } }
    sign_in @player

    get card_path

    assert_equal [ "Lea", "Max", "Friend 0" ], section_names
    assert_select ".card-trade-section a.card-trade-section__more[href='#card-trade-sheet'][aria-haspopup=dialog]", "Show 1 more friend"
    assert_equal [ "Lea", "Max", "Friend 0", "Friend 1" ], css_select("#card-trade-sheet .card-trade__name").map { it.text.strip }
    assert_includes css_select("#card-trade-sheet .card-trade__row a.button").map { it["href"] }, opener_for(others.last)

    get card_path(locale: :fr)
    assert_select ".card-trade-section__more", "Afficher 1 ami de plus"
  end

  test "in the app the rest of the friends open on their own page, every friend listed with a way to propose" do
    hold(@lea, @portal.id, 5)
    hold(@max, @portal.id, 4)
    others = [ 3, 2 ].map.with_index { |copies, index| befriend_new("Friend #{index}").tap { hold(it, @portal.id, copies) } }
    sign_in @player
    holders = card_holders_path(slug: catalog_cards(:portal).slug, number: @portal.season.number, locale: :en)

    get card_path, headers: { "User-Agent" => APP }
    assert_select ".card-trade-section a.card-trade-section__more[href='#{holders}']", "Show 1 more friend"

    get holders, headers: { "User-Agent" => APP }
    assert_response :success
    assert_select "body.sheet-body section#card-trade-sheet.sheet-page h1", "Trade for this card"
    assert_equal [ "Lea", "Max", "Friend 0", "Friend 1" ], css_select(".card-trade__name").map { it.text.strip }
    assert_includes css_select(".card-trade__row a.button").map { it["href"] }, opener_for(others.last)
    assert_select "header.top-bar", 0
  end

  test "a visitor is led to sign in instead of the friends holding a card" do
    get card_holders_path(slug: catalog_cards(:portal).slug, number: @portal.season.number, locale: :en)

    assert_response :see_other
  end

  test "a friend holding only another edition is listed with that edition, and the trade asks for it" do
    other = portal_edition(2, rarity: "rare")
    hold(@lea, other, 1)
    sign_in @player

    get card_path

    assert_equal [ "Lea" ], section_names
    assert_select ".card-trade-section .card-trade__edition", "Rare: S2"
    assert_equal [ new_trade_path(friend: @lea.token, ask: "#{catalog_cards(:portal).slug}--s2", locale: :en) ], proposals
  end

  test "a card the player owns has no trade section" do
    hold(@player, @portal.id, 1)
    hold(@lea, @portal.id, 2)
    sign_in @player

    get card_path

    assert_response :success
    assert_select ".card-trade-section", 0
  end

  test "no friend holding the card, no section" do
    sign_in @player

    get card_path

    assert_select ".card-trade-section", 0
  end

  test "a visitor sees no trade section" do
    hold(@lea, @portal.id, 2)

    get card_path

    assert_select ".card-trade-section", 0
  end

  test "a private friend and a reserved copy are not offered" do
    hold(@lea, @portal.id, 2)
    hold(@max, @portal.id, 1, reserved: 1)
    @lea.update_columns(visibility: "private")
    sign_in @player

    get card_path

    assert_select ".card-trade-section", 0
  end

  test "a friend already asked shows without a way to propose" do
    hold(@lea, @portal.id, 2)
    hold(@max, @portal.id, 1)
    ask(@lea)
    sign_in @player

    get card_path

    assert_equal [ opener_for(@max) ], proposals
    assert_select ".card-trade-section .card-trade__row--asked", text: /Lea.*Already asked/m
  end

  test "reading the card writes nothing" do
    hold(@lea, @portal.id, 2)
    sign_in @player

    assert_no_difference -> { Game::Trade.count } do
      get card_path
    end
  end

  test "choosing a friend opens the trade board with the card asked for and sends nothing" do
    hold(@lea, @portal.id, 1)
    sign_in @player
    get card_path
    opener = proposals.sole

    assert_no_difference -> { Game::Trade.count } do
      get opener
    end

    assert_response :success
    assert_equal "true", css_select("#trade-board").sole["data-trade-board-prefilled-value"]
    assert_equal [ [ "friend", portal_key, 1 ] ], board_lines
    assert_select "#trade-draft-form input[name=friend][value=?]", @lea.token
  end

  test "a card asked from its page is placed from a single copy, not a suggestion's duplicate rule" do
    hold(@lea, @portal.id, 1)
    sign_in @player

    get new_trade_path(friend: @lea.token, take: [ portal_key ], locale: :en)
    assert_empty board_lines

    get new_trade_path(friend: @lea.token, ask: { portal_key => "1" }, locale: :en)
    assert_empty board_lines
  end

  test "the board sends the trade only once the player sends it" do
    hold(@lea, @portal.id, 1)
    sign_in @player

    assert_difference -> { Game::Trade.count }, 1 do
      post trades_path(locale: :en), params: { friend: @lea.token, take: { portal_key => "1" } }
    end

    trade = Game::Trade.order(:id).last
    assert_equal [ @player.id, @lea.id ], [ trade.proposer_id, trade.recipient_id ]
    assert_equal({ "offer" => {}, "request" => { @portal.id => 1 } }, trade_sides(trade))
  end

  test "the section speaks French" do
    hold(@lea, @portal.id, 2)
    sign_in @player

    get card_path(locale: :fr)

    assert_select "#card-trade-heading", "Échanger pour cette carte"
    assert_select ".card-trade-section .card-trade__copies", text: "2 exemplaires"
    assert_select ".card-trade-section a.button", "Proposer"
  end
end

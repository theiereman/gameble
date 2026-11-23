require "test_helper"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/steam_sign_in"

class CardOrderButtonTest < ActionDispatch::IntegrationTest
  include Holdings
  include MarketSettings
  include SteamSignIn

  def order_buttons = css_select(".card-detail__card-links .button--primary")

  test "a player who holds no edition gets PLACE AN ORDER, the detail's one filled button, before Share" do
    open_market!(first_opened_at: 1.day.ago)
    sign_in(accounts_players(:moderator))

    get card_path(locale: :en, slug: "tin-soldier")

    assert_equal [ new_market_card_order_path(locale: :en, slug: "tin-soldier", from: "card") ], order_buttons.map { it["href"] }
    assert_equal 1, css_select(".card-detail .button--primary").size
    assert_equal "Place an order", css_select(".card-detail__card-links .button").first.text.strip
  end

  test "a friend holding the card leaves PLACE AN ORDER the one filled button, the proposals secondary" do
    open_market!(first_opened_at: 1.day.ago)
    player = accounts_players(:moderator)
    friend = accounts_players(:administrator)
    low, high = [ player.id, friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    hold(friend, catalog_card_seasons(:common_card_one).id, 1)
    sign_in(player)

    get card_path(locale: :en, slug: "tin-soldier")

    assert_select ".card-trade__row .button--secondary", 1
    assert_equal 1, css_select(".card-detail .button--primary").size
  end

  test "a holder, a closed market and a suspended one draw no order button" do
    player = accounts_players(:moderator)
    hold(player, catalog_card_seasons(:common_card_one).id, 1)
    sign_in(player)
    open_market!(first_opened_at: 1.day.ago)
    get card_path(locale: :en, slug: "tin-soldier")
    assert_empty order_buttons

    close_market!(first_opened_at: 1.day.ago)
    get card_path(locale: :en, slug: "green-hills")
    assert_empty order_buttons
  end

  test "a visitor browsing a set sees the button disabled" do
    open_market!(first_opened_at: 1.day.ago)
    set_id = Catalog::Set.insert_all!([ { season_id: catalog_seasons(:one).id, kind: "theme", key: "puzzle", params: { "theme" => "puzzle" } } ],
      returning: :id).rows.flatten.first
    Catalog::SetMembership.insert_all!([ { set_id:, card_season_id: catalog_card_seasons(:common_card_one).id, position: 1 } ])

    get card_season_path(locale: :en, slug: "tin-soldier", number: 1, set_kind: "theme", set_key: "puzzle")

    assert_select ".card-detail__card-links button.button--primary[disabled]", "Place an order"
  end
end

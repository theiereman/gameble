require "test_helper"
require_relative "../support/steam_sign_in"

class MarketsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  test "a visitor reads the market's plans, in French, without the players' tabs" do
    get market_path(locale: :fr)

    assert_response :success
    assert_select "h1", "La Confrérie construit le marché"
    assert_select ".market-teaser__plan", 4
    assert_select ".tab-bar", false
    assert_select "[style]", false
  end

  test "a player reads it in English, inside the shell" do
    sign_in(accounts_players(:player))

    get market_path(locale: :en)

    assert_response :success
    assert_select "h1", "The Brotherhood is building the market"
    assert_select ".tab-bar"
  end

  test "the landing leads to the leaderboard beside the feed, and to the market beside the roadmap" do
    get home_path(locale: :fr)

    assert_select ".landing-live__links a.button--link[href=?]", feed_path(locale: :fr)
    assert_select ".landing-live__links a.button--link[href=?]", fortune_register_path(locale: :fr), "Voir Le Chattomètre"
    assert_select ".landing-roadmap__links a.button--link[href=?]", roadmap_path(locale: :fr)
    assert_select ".landing-roadmap__links a.button--link[href=?]", market_path(locale: :fr), "Visiter le chantier du marché"
  end
end

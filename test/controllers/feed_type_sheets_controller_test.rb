require "test_helper"
require_relative "../support/steam_sign_in"

class FeedTypeSheetsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  APP = "Gameble Android; Hotwire Native Android; Turbo Native Android; bridge-components: [sign-in share haptics]".freeze

  setup { sign_in(accounts_players(:player)) }

  test "the feed's types are served on their own, each a link to the feed it filters, the chosen one marked" do
    get feed_types_path(tab: "friends", filter: "pulls", locale: :en), headers: { "User-Agent" => APP }

    assert_response :success
    assert_select "body.sheet-body section#feed-types.sheet-page h1.modal__title"
    assert_select "a.feed__filter[href='#{feed_path(tab: "friends", filter: "trades", locale: :en)}']"
    assert_select "a.feed__filter[aria-current=true][href='#{feed_path(tab: "friends", filter: "pulls", locale: :en)}']"
    assert_select "header.top-bar", 0
  end

  test "an unknown type or tab falls back to every entry" do
    get feed_types_path(tab: "everyone", filter: "secrets", locale: :en), headers: { "User-Agent" => APP }

    assert_select "a.feed__filter[aria-current=true][href='#{feed_path(locale: :en)}']"
  end

  test "in the app the feed's type opener leads to that page; in a browser it raises the sheet in place" do
    get feed_path(filter: "pulls", locale: :en), headers: { "User-Agent" => APP }
    assert_select "a.feed__type-opener[href='#{feed_types_path(filter: "pulls", locale: :en)}']"

    get feed_path(filter: "pulls", locale: :en)
    assert_select "a.feed__type-opener[href='#feed-types'][data-bottom-sheet-opens=feed-types]"
  end
end

require "test_helper"
require_relative "../support/steam_sign_in"

class OwnProfileSheetsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  APP = "Gameble Android; Hotwire Native Android; Turbo Native Android; bridge-components: [sign-in share haptics]".freeze

  setup { sign_in(accounts_players(:player)) }

  test "each profile sheet is served on its own, its title over its choices, without the screen's chrome" do
    { title: "me-title-sheet", avatar: "me-avatar-sheet", back: "me-back-sheet" }.each do |sheet, id|
      get me_sheet_path(sheet, locale: :en), headers: { "User-Agent" => APP }

      assert_response :ok
      assert_select "body.sheet-body section##{id}.sheet-page h1.sheet-page__title"
      assert_select "dialog", 0
      assert_select "header.top-bar", 0
    end
  end

  test "a sheet that is not the profile's is not found" do
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/en/me/sheets/settings") }
  end

  test "a visitor is led to sign in instead of a sheet" do
    delete session_path

    get me_sheet_path(:title, locale: :en), headers: { "User-Agent" => APP }

    assert_response :see_other
  end

  test "in the app the profile's openers lead to the sheets' pages; in a browser they raise the sheets in place" do
    get me_path(locale: :en), headers: { "User-Agent" => APP }
    assert_select "a[href='#{me_sheet_path(:title, locale: :en)}']"
    assert_select "a[href='#{me_sheet_path(:avatar, locale: :en)}']"
    assert_select "a[href='#{me_sheet_path(:back, locale: :en)}']"

    get me_path(locale: :en)
    assert_select "a[href='#me-title-sheet'][data-bottom-sheet-opens=me-title-sheet]"
  end

  test "in the app a title chosen in its sheet closes the sheet and refreshes the profile under it" do
    patch personalization_title_path(locale: :en), params: { title: "" }, headers: { "User-Agent" => APP }

    assert_response :redirect
    assert_equal "/refresh_historical_location", URI(response.location).path
  end

  test "in a browser a title chosen leads back to the profile" do
    patch personalization_title_path(locale: :en), params: { title: "" }

    assert_redirected_to me_path(locale: :en)
  end
end

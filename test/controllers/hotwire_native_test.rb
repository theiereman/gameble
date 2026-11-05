require "test_helper"
require_relative "../support/steam_sign_in"

class HotwireNativeTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  APP = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 " \
    "Hotwire Native iOS; Turbo Native iOS; bridge-components: [haptics push-permission share]".freeze

  setup { sign_in(accounts_players(:player)) }

  test "in the app, the native tab bar takes the web one's place and the haptics and sheet bridges listen" do
    get home_path(locale: :en), headers: { "User-Agent" => APP }

    assert_select "html[data-native-app]"
    assert_select "nav.tab-bar", 0
    assert_select "[data-controller~='bridge--haptics'][data-controller~='bridge--sheet']"
    assert_select "meta[name=view-transition]", 0
  end

  test "a visitor in the app is led straight to sign in instead of the landing; a browser's visitor sees the landing" do
    delete session_path

    get home_path(locale: :en), headers: { "User-Agent" => APP }
    assert_redirected_to sign_in_path(locale: :en)

    get home_path(locale: :en)
    assert_response :ok
  end

  test "in a browser, the page keeps its web chrome" do
    get home_path(locale: :en)

    assert_select "html[data-native-app]", 0
    assert_select "nav.tab-bar"
    assert_select "[data-controller~='bridge--haptics']", 0
  end

  test "the app's settings offer its notifications, hidden until the bridge shows them; a browser's do not" do
    get settings_path(locale: :en), headers: { "User-Agent" => APP }
    assert_select "li.settings-row[hidden][data-controller='bridge--push-permission'][data-bridge--push-permission-url-value='/en/native/push-devices']"

    get settings_path(locale: :en)
    assert_select "[data-controller='bridge--push-permission']", 0
  end

  test "in the app, the sign-in hands over to the system browser instead of offering its buttons" do
    delete session_path
    get sign_in_path(locale: :fr), headers: { "User-Agent" => APP }

    assert_select "[data-controller='bridge--sign-in'] button[data-action='bridge--sign-in#start']", text: "Se connecter dans le navigateur"
    assert_select ".steam-sign-in", 0
  end

  test "each app's path configuration covers every page, swaps a page for itself with other parameters, and never pulls to refresh" do
    %w[ios_v1 android_v1].each do |name|
      rules = JSON.parse(Rails.public_path.join("configurations/#{name}.json").read).fetch("rules")

      assert_equal [ ".*" ], rules.first.fetch("patterns"), name
      assert_equal "replace", rules.first.dig("properties", "query_string_presentation"), name
      assert rules.none? { |rule| rule.dig("properties", "pull_to_refresh_enabled") }, name
      %w[/fr/me/sheets/title /en/feed/types /fr/cards/portal/seasons/1/holders].each do |sheet_path|
        rule = rules.reverse.find { |candidate| candidate["patterns"].any? { Regexp.new(it).match?(sheet_path) } }
        assert_equal "modal", rule.dig("properties", "context"), "#{name} #{sheet_path}"
      end
      %w[/en/feed /fr/cards/portal/seasons/1].each do |screen|
        rule = rules.reverse.find { |candidate| candidate["patterns"].any? { Regexp.new(it).match?(screen) } }
        assert_equal "default", rule.dig("properties", "context"), "#{name} #{screen}"
      end
    end
  end
end

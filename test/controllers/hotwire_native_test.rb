require "test_helper"
require_relative "../support/steam_sign_in"

class HotwireNativeTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  APP = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 " \
    "Hotwire Native iOS; Turbo Native iOS; bridge-components: [haptics push-permission share]".freeze

  setup { sign_in(accounts_players(:player)) }

  test "in the app, the native tab bar takes the web one's place and the haptics bridge listens" do
    get home_path(locale: :en), headers: { "User-Agent" => APP }

    assert_select "html[data-native-app]"
    assert_select "nav.tab-bar", 0
    assert_select "[data-controller='bridge--haptics']"
    assert_select "meta[name=view-transition]", 0
  end

  test "in a browser, the page keeps its web chrome" do
    get home_path(locale: :en)

    assert_select "html[data-native-app]", 0
    assert_select "nav.tab-bar"
    assert_select "[data-controller='bridge--haptics']", 0
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

  test "each app's path configuration is valid JSON with a rule for every page" do
    %w[ios_v1 android_v1].each do |name|
      rules = JSON.parse(Rails.public_path.join("configurations/#{name}.json").read).fetch("rules")

      assert_equal [ ".*" ], rules.first.fetch("patterns"), name
      assert rules.any? { |rule| rule["patterns"].any? { Regexp.new(it).match?("/fr/booster") } }, name
    end
  end
end

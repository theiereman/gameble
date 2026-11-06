require "test_helper"
require_relative "../support/steam_sign_in"

class HotwireNativeTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  APP = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 " \
    "Hotwire Native iOS; Turbo Native iOS; bridge-components: [haptics push-permission share]".freeze

  APP_WITH_BAR = APP.sub("share]", "share top-bar]").freeze

  setup { sign_in(accounts_players(:player)) }

  test "in the app, the native tab bar takes the web one's place and the haptics and sheet bridges listen" do
    get home_path(locale: :en), headers: { "User-Agent" => APP }

    assert_select "html[data-native-app]"
    assert_select "nav.tab-bar", 0
    assert_select "[data-controller~='bridge--haptics'][data-controller~='bridge--sheet']"
    assert_select "meta[name=view-transition]", 0
  end

  test "in the app, a screen names itself to the app and carries no way back of its own" do
    get card_season_path(slug: catalog_cards(:portal).slug, number: catalog_card_seasons(:portal_one).season.number, locale: :en), headers: { "User-Agent" => APP_WITH_BAR }

    assert_select "[data-controller~='bridge--back']", 0
    assert_select "[data-controller~='previous-screen']", 0
    assert_select ".top-bar__previous, .top-bar__phone-back, .top-bar__bridge", 0
    assert_select "div[hidden][data-controller~='bridge--screen'][data-bridge--screen-label-value=Card]"

    get home_path(locale: :fr), headers: { "User-Agent" => APP_WITH_BAR }
    assert_select "div[hidden][data-controller~='bridge--screen'][data-bridge--screen-label-value=Pont]"
  end

  test "an app with the native bar gets the same counts, bell and menu on every screen, without a page bar of its own" do
    [ home_path(locale: :en), library_path(locale: :en), booster_path(locale: :en), me_path(locale: :en) ].each do |path|
      get path, headers: { "User-Agent" => APP_WITH_BAR }

      assert_select "html[data-native-app][data-native-bar]"
      assert_select ".top-bar__start", 0
      assert_select "header.top-bar[data-controller~='top-bar-scroll']", 0
      assert_select ".rarity-counter", 0
      assert_select ".top-bar__end[data-controller='bridge--top-bar'][data-action='click->bridge--top-bar#navigate']" do
        assert_select ".bank-counter__item:not(.bank-counter__item--special) .bank-counter__count", 1, path
        assert_select ".bank-counter__item--special .bank-counter__count", 1, path
        assert_select "#bell-panel[popover]"
        assert_select "#phone-menu-panel[popover]"
        assert_select "#phone-menu-badge"
        assert_select "svg.player-chip__avatar"
      end
    end
  end

  test "with the native bar, the collection's progress moves from the bar to the top of the page" do
    get library_path(locale: :en), headers: { "User-Agent" => APP_WITH_BAR }

    assert_select ".top-bar__end .collection-status", 0
    assert_select "main > .native-status:first-child .collection-status[popovertarget=rarity-legend]"
    assert_select "#rarity-legend", 1
  end

  test "an app that does not declare the native bar keeps its page bar" do
    get library_path(locale: :en), headers: { "User-Agent" => APP }

    assert_select "html[data-native-app]"
    assert_select "html[data-native-bar]", 0
    assert_select ".top-bar__start"
    assert_select ".top-bar__end .collection-status"
    assert_select ".native-status", 0
    assert_select "[data-controller~='bridge--top-bar']", 0
  end

  test "a browser keeps its page bar" do
    get library_path(locale: :en)

    assert_select "html[data-native-bar]", 0
    assert_select ".top-bar__start > a.top-bar__previous[data-controller=previous-screen]"
    assert_select ".top-bar__end .collection-status"
    assert_select ".native-status", 0
  end

  test "a visitor in an app with the native bar has no native bar to lean on" do
    delete session_path

    get sign_in_path(locale: :en), headers: { "User-Agent" => APP_WITH_BAR }

    assert_select "html[data-native-bar]", 0
  end

  test "a sheet served on its own has neither the bar's room nor a header" do
    get me_sheet_path(sheet: :title, locale: :en), headers: { "User-Agent" => APP_WITH_BAR }

    assert_response :success
    assert_select "html[data-native-bar]", 0
    assert_select "header.top-bar", 0
  end

  test "in the app, the daily capsule is collected on the bridge: the capsule screen does not offer it and the bell leads there" do
    get booster_path(locale: :en), headers: { "User-Agent" => APP }
    assert_select "section#booster"
    assert_select "#booster-daily", 0

    get home_path(locale: :en), headers: { "User-Agent" => APP }
    assert_select "#daily-booster form[action='/en/daily-bonus']"

    get bell_path(locale: :en), headers: { "User-Agent" => APP, "Turbo-Frame" => "bell-items" }
    assert_select "li#bell-daily[data-bell-lasting=true][data-bell-path='/en'] a[href='/en']"
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

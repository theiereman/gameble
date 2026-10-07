require "test_helper"

# The settings screen and the motion switch (EXPERIENCE.md, Reduced motion;
# AD-27): the player's setting, else the cookie, else the system, rendered as
# `html[data-motion]` and in the view-transition meta.
class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    @player = accounts_players(:player)
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(player = @player)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    post "/auth/steam", params: { origin: "/en" }
    follow_redirect!
    assert session[:player_id]
  end

  def reduced? = css_select("html[data-motion=reduced]").any?
  def transition_meta? = css_select("meta[name=view-transition]").any?

  # The settings screen

  test "a player's settings screen: language, reduced motion and sign-out, the system chosen by default" do
    sign_in

    get settings_path(locale: :fr)

    assert_response :success
    assert_select "title", /Profil et paramètres/
    assert_select "main h1", "Profil et paramètres"
    assert_select ".settings-row", 3
    assert_equal [ "Langue", "Animations réduites", "Session" ], css_select(".settings-row__label").map(&:text)
    assert_select "[role=group][aria-labelledby=settings-language] a.segmented__option", 2
    assert_select "a.segmented__option[href='/fr/settings'][aria-current=true][lang=fr]", "Français"
    assert_select "a.segmented__option[href='/en/settings'][lang=en]:not([aria-current])", "English"
    assert_select "form[action='/fr/settings'][data-turbo=false] input[name=_method][value=patch]"
    assert_select "button.segmented__option[name=reduced_motion]", 3
    assert_select "button[name=reduced_motion][value=system][aria-pressed=true]", "Système"
    assert_select "button[name=reduced_motion][value=on][aria-pressed=false]", "Oui"
    assert_select "button[name=reduced_motion][value=off][aria-pressed=false]", "Non"
    assert_select "form[action=?][data-turbo=false] button", "/session?locale=fr", text: "Se déconnecter"
    assert_select ".top-bar a.button[href='/fr']", /Pont/
  end

  test "the settings screen in English, and the player's choice marked" do
    @player.update!(reduced_motion: true)
    sign_in

    get settings_path(locale: :en)

    assert_select "main h1", "Profile and settings"
    assert_equal [ "Language", "Reduced motion", "Session" ], css_select(".settings-row__label").map(&:text)
    assert_select "button[name=reduced_motion][value=on][aria-pressed=true]", "Yes"
    assert_select "button[name=reduced_motion][value=system][aria-pressed=false]", "System"
    assert_select "button[name=reduced_motion][value=off][aria-pressed=false]", "No"
  end

  test "an explicit no is marked too" do
    @player.update!(reduced_motion: false)
    sign_in

    get settings_path(locale: :en)

    assert_select "button[name=reduced_motion][value=off][aria-pressed=true]", "No"
    assert_select "button[aria-pressed=true]", 1
  end

  test "a visitor is sent home and asked to sign in; nothing is written" do
    get settings_path(locale: :en)
    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("authorization.sign_in_required", locale: :en), flash[:alert]

    patch settings_path(locale: :en), params: { reduced_motion: "on" }
    assert_redirected_to home_path(locale: :en)
    assert_nil cookies[:motion]
    assert_nil @player.reload.reduced_motion
  end

  test "reading the settings writes nothing: no cookie, no setting" do
    sign_in

    get settings_path(locale: :en)

    assert_not_includes Array(response.headers["Set-Cookie"]).join("\n"), "motion="
    assert_nil @player.reload.reduced_motion
  end

  # Writing a setting

  { "on" => [ true, "reduced" ], "off" => [ false, "full" ] }.each do |choice, (value, cookie)|
    test "choosing #{choice} stores #{value} on the player and mirrors it in the cookie" do
      sign_in

      patch settings_path(locale: :en), params: { reduced_motion: choice }

      assert_redirected_to settings_path(locale: :en)
      assert_response :see_other
      assert_equal value, @player.reload.reduced_motion
      assert_equal cookie, cookies[:motion]
      assert_match(/motion=#{cookie}.*HttpOnly.*SameSite=Lax/im, Array(response.headers["Set-Cookie"]).join("\n"))
    end
  end

  test "choosing the system empties the setting and removes the cookie" do
    @player.update!(reduced_motion: true)
    sign_in
    cookies[:motion] = "reduced"

    patch settings_path(locale: :en), params: { reduced_motion: "system" }

    assert_redirected_to settings_path(locale: :en)
    assert_nil @player.reload.reduced_motion
    assert_predicate cookies[:motion], :blank?
  end

  [ nil, "", "yes", "true", "reduced", [ "on" ] ].each do |choice|
    test "#{choice.inspect} is no choice: refused with its message, nothing changes" do
      @player.update!(reduced_motion: true)
      sign_in

      patch settings_path(locale: :fr), params: { reduced_motion: choice }

      assert_redirected_to settings_path(locale: :fr)
      assert_equal I18n.t("errors.accounts.invalid_setting", locale: :fr), flash[:alert]
      assert_equal true, @player.reload.reduced_motion
      assert_nil cookies[:motion]
    end
  end

  test "a change is a PATCH: no GET writes it" do
    sign_in

    get settings_path(locale: :en, reduced_motion: "on")

    assert_nil @player.reload.reduced_motion
    assert_nil cookies[:motion]
  end

  # The one switch: setting, else cookie, else system

  test "by default nothing is forced: no data-motion, and the view-transition meta renders" do
    sign_in

    get home_path(locale: :en)

    assert_not reduced?
    assert transition_meta?
  end

  test "a player's reduced motion sets html[data-motion=reduced] and renders no view-transition meta, on every page" do
    @player.update!(reduced_motion: true)
    sign_in

    [ home_path(locale: :en), settings_path(locale: :en), booster_path(locale: :en), library_path(locale: :fr) ].each do |path|
      get path

      assert reduced?, path
      assert_not transition_meta?, path
    end
  end

  test "a player's explicit no forces nothing" do
    @player.update!(reduced_motion: false)
    sign_in

    get home_path(locale: :en)

    assert_not reduced?
    assert transition_meta?
  end

  test "a visitor follows the cookie: reduced, no meta" do
    cookies[:motion] = "reduced"

    get home_path(locale: :en)

    assert reduced?
    assert_not transition_meta?
  end

  test "a visitor with an explicit-no cookie, or none, or a junk one, is forced nothing" do
    [ "full", nil, "", "reduced ", "1" ].each do |value|
      cookies[:motion] = value
      get home_path(locale: :en)

      assert_not reduced?, value.inspect
      assert transition_meta?, value.inspect
    end
  end

  test "the player's setting wins over a cookie that says otherwise" do
    @player.update!(reduced_motion: false)
    sign_in
    cookies[:motion] = "reduced"

    get home_path(locale: :en)

    assert_not reduced?

    @player.update!(reduced_motion: true)
    cookies[:motion] = "full"
    get home_path(locale: :en)

    assert reduced?
  end

  test "a signed-in player who follows the system ignores the cookie" do
    sign_in
    cookies[:motion] = "reduced"

    get home_path(locale: :en)

    assert_not reduced?
    assert transition_meta?
  end

  test "a visitor does not see the settings row on the PLUS screen" do
    get more_path(locale: :en)

    assert_response :success
    assert_select ".plus__list > li", 3
    assert_select ".plus__list a[href='/en/settings']", false
  end

  test "the public pages and the signed-out card page follow the cookie too" do
    cookies[:motion] = "reduced"

    get brother_path(token: @player.token, locale: :en)

    assert reduced?
    assert_not transition_meta?
  end

  # Sign-out keeps the preference

  test "signing out writes the player's setting to the cookie, and the signed-out hub follows it" do
    @player.update!(reduced_motion: true)
    sign_in

    delete session_path(locale: :en)

    assert_equal "reduced", cookies[:motion]
    follow_redirect!
    assert_select ".hub-invitation"
    assert reduced?
    assert_not transition_meta?
  end

  test "signing out with an explicit no keeps it as a cookie; with the system, removes the cookie" do
    @player.update!(reduced_motion: false)
    sign_in
    delete session_path(locale: :en)
    assert_equal "full", cookies[:motion]

    @player.update!(reduced_motion: nil)
    sign_in
    cookies[:motion] = "reduced"
    delete session_path(locale: :en)

    assert_predicate cookies[:motion], :blank?
    follow_redirect!
    assert_not reduced?
  end

  test "the player menu links to the settings, and the tab bar's PLUS opens the rest of the ship" do
    sign_in

    get home_path(locale: :en)

    assert_select "#player-menu a.player-menu__item[href='/en/settings']", "Settings"
    assert_select "a.tab-bar__tab[href='/en/more']", /More/
  end

  test "the PLUS screen lists the screens that are not tabs, settings among them" do
    sign_in

    get more_path(locale: :fr)

    assert_response :success
    assert_select "main h1", "Pont de commandement"
    assert_select ".hub__subtitle", "Le reste du vaisseau"
    assert_select ".plus__list > li", 4
    assert_select ".plus__list a.menu-item[href='/fr/settings']", /Profil et paramètres/
    assert_select ".plus__list a.menu-item[href='/fr/friends']", /Amis/
    assert_select ".plus__list .menu-item[aria-disabled=true]", 2
    assert_select "a.tab-bar__tab[href='/fr/more'][aria-current=page]"
  end

  test "the settings screen is under the PLUS tab, with a contextual phone back" do
    sign_in

    get settings_path(locale: :fr)

    assert_select "a.tab-bar__tab[href='/fr/more'][aria-current=page]"
    assert_select "a.tab-bar__tab[href='/fr'][aria-current]", false
    assert_select ".top-bar a.top-bar__phone-back[href='/fr/more']", /Plus/
  end

  test "the hub tab is current on the hub only" do
    sign_in

    get more_path(locale: :en)

    assert_select "a.tab-bar__tab[href='/en'][aria-current]", false
  end
end

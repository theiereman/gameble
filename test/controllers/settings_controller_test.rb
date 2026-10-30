require "test_helper"
require_relative "../support/steam_sign_in"

# The settings screen and the motion switch: the player's setting, else the
# cookie, else the system, rendered as `html[data-motion]` ("reduced", "full"
# or absent) and in the view-transition meta.
class SettingsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
  end

  def reduced? = forced_motion == "reduced"
  def forced_motion = css_select("html").first["data-motion"]
  def transition_meta? = css_select("meta[name=view-transition]").any?

  def open_trade(proposer:, recipient:)
    low, high = [ proposer.id, recipient.id ].minmax
    Game::Friendship.find_or_create_by!(low_player_id: low, high_player_id: high)
    offered = catalog_card_seasons(:portal_one).id
    requested = catalog_card_seasons(:rare_card_one).id
    Game::Holding.find_or_create_by!(player_id: proposer.id, card_season_id: offered).increment!(:quantity)
    Game::Holding.find_or_create_by!(player_id: recipient.id, card_season_id: requested).increment!(:quantity)
    Game::ProposeTrade.new.call(player: proposer, recipient:, offer: { offered => 1 }, request: { requested => 1 }).value!
  end

  # The settings screen

  test "a player's settings screen: language, visibility, reduced motion, sign-out, the account, support and the legal link, the system chosen by default" do
    sign_in(@player)

    get settings_path(locale: :fr)

    assert_response :success
    assert_select "title", /Paramètres/
    assert_select "main h1", "Paramètres"
    assert_select ".settings-row", 9
    assert_equal [ "Langue", "Visibilité du profil", "Animations réduites", "Connexions", "Mes données", "Session", "Compte", "Soutenir" ], css_select(".settings-row__label").map(&:text)
    assert_select "[role=group][aria-labelledby=settings-language] a.segmented__option[data-locale-choice][data-turbo-action=replace]", 2
    assert_select "a.segmented__option[href='/fr/settings'][aria-current=true][lang=fr]", "Français"
    assert_select "a.segmented__option[href='/en/settings'][lang=en]:not([aria-current])", "English"
    assert_select "form[action='/fr/settings'][data-turbo=false] input[name=_method][value=patch]"
    assert_select "[role=group][aria-labelledby=settings-visibility] button[name=visibility]", 3
    assert_select "form[action='/fr/settings/visibility'] button[name=visibility][value=public][aria-pressed=true]", "Public"
    assert_select "button[name=visibility][value=friends_only][aria-pressed=false]", "Amis uniquement"
    assert_select "button[name=visibility][value=private][aria-pressed=false]", "Privé"
    assert_select "button.segmented__option[name=reduced_motion]", 3
    assert_select "button[name=reduced_motion][value=system][aria-pressed=true]", "Système"
    assert_select "button[name=reduced_motion][value=on][aria-pressed=false]", "Oui"
    assert_select "button[name=reduced_motion][value=off][aria-pressed=false]", "Non"
    assert_select "form[action=?][data-turbo=false] button", "/session?locale=fr", text: "Se déconnecter"
    support = css_select("li.settings-row a.settings-row__support").sole
    assert_equal [ "https://buymeacoffee.com/theiereman", "_blank", "Soutenir (nouvel onglet)" ],
      [ support["href"], support["target"], support.text.squish ]
    assert_includes support["rel"].split, "noopener"
    assert_select ".settings__list > li:last-child a.button--link[href='/fr/legal']", "Mentions légales"
    assert_select ".top-bar a.button[href='/fr']", /Pont/
  end

  test "the MES DONNÉES row posts the export, a full page load without JavaScript, with the strings its script shows" do
    sign_in(@player)

    get settings_path(locale: :fr)

    form = css_select("form[action='/fr/settings/export'][method=post][data-turbo=false][data-controller=data-export]").sole
    assert_equal "submit->data-export#export", form["data-action"]
    assert_equal [ "Préparation…", "Réessayer", "Export prêt", "Télécharger" ],
      %w[preparing retry ready-title download].map { form["data-data-export-#{it}-value"] }
    assert_select form, "button[type=submit].button--secondary.button--small", "Exporter"
    assert_select form, "p.settings-row__error[role=alert][hidden][data-data-export-target=error]", ""
    assert_select form, ".settings-row__actions button[type=submit] + a.settings-row__download[hidden][data-data-export-target=download][href='/fr/settings/export']:not([download])", "Télécharger"
    assert_nil form["data-data-export-time-format-value"]
    assert_select form, "p.settings-row__note[hidden][data-data-export-target=lastExport]"
    assert_select form, "p.settings-row__note[hidden][data-data-export-target=nextExport]"
    assert_select form, "button[type=submit]:not([disabled])"
    assert_equal [ "300", nil ], [ form["data-data-export-interval-value"], form["data-data-export-next-export-at-value"] ]

    get settings_path(locale: :en)
    assert_select "form[action='/en/settings/export'] button[type=submit]", "Export"
  end

  test "the time of the last export shows under the buttons, for the browser to show in its own time" do
    Accounts::RecordExport.new.call(player: @player, at: Time.utc(2026, 10, 4, 7, 5)) { "{}" }.value!
    sign_in(@player)

    get settings_path(locale: :fr)
    assert_select "p.settings-row__note:not([hidden])", /Dernier export :\s+2026-10-04 07:05 UTC/
    assert_select "p.settings-row__note time[datetime='2026-10-04T07:05:00Z'][data-controller=local-time][data-local-time-style-value=date-time-year]" \
      "[data-data-export-target=time]", "2026-10-04 07:05 UTC"

    assert_select "a.settings-row__download:not([hidden])[href='/fr/settings/export'][download='gameble-export-2026-10-04.json']", "Télécharger"

    get settings_path(locale: :en)
    assert_select "p.settings-row__note time", "2026-10-04 07:05 UTC"
  end

  test "once the browser has sent its zone, the time of the last export is already the local one the browser shows" do
    Accounts::RecordExport.new.call(player: @player, at: Time.utc(2026, 10, 4, 7, 5)) { "{}" }.value!
    sign_in(@player)
    cookies[LocalTimeHelper::TIME_ZONE_COOKIE] = "Europe/Paris"

    get settings_path(locale: :fr)
    assert_select "p.settings-row__note time[datetime='2026-10-04T07:05:00Z']", "4 oct. 2026 à 09h05"

    get settings_path(locale: :en)
    assert_select "p.settings-row__note time[datetime='2026-10-04T07:05:00Z']", "Oct 4, 2026, 09:05"
  end

  test "within five minutes of the last export, EXPORTER is disabled and says when the next export is allowed" do
    sign_in(@player)

    travel_to Time.utc(2026, 10, 14, 9, 32) do
      Accounts::RecordExport.new.call(player: @player, at: Time.utc(2026, 10, 14, 9, 30)) { "{}" }.value!
      get settings_path(locale: :fr)
    end

    form = css_select("form[data-controller=data-export]").sole
    assert_select form, "button[type=submit][disabled]", "Exporter"
    assert_select form, "p.settings-row__note:not([hidden]) time[datetime='2026-10-14T09:35:00Z'][data-data-export-target=nextTime]", "2026-10-14 09:35 UTC"
    assert_select form, "p.settings-row__note:not([hidden])", /Prochain export :/
    assert_equal "2026-10-14T09:35:00Z", form["data-data-export-next-export-at-value"]
  end

  test "the settings screen in English, and the player's choice marked" do
    @player.update!(reduced_motion: true)
    sign_in(@player)

    get settings_path(locale: :en)

    assert_select "main h1", "Settings"
    assert_equal [ "Language", "Profile visibility", "Reduced motion", "Session", "Sign-ins", "My data", "Account", "Support" ], css_select(".settings-row__label").map(&:text)
    assert_select "button[name=reduced_motion][value=on][aria-pressed=true]", "Yes"
    assert_select "button[name=reduced_motion][value=system][aria-pressed=false]", "System"
    assert_select "button[name=reduced_motion][value=off][aria-pressed=false]", "No"
    assert_select "li.settings-row a.settings-row__support", "Support (new tab)"
  end

  test "an explicit no is marked too" do
    @player.update!(reduced_motion: false)
    sign_in(@player)

    get settings_path(locale: :en)

    assert_select "button[name=reduced_motion][value=off][aria-pressed=true]", "No"
    assert_select "button[name=reduced_motion][aria-pressed=true]", 1
  end

  test "a visitor is sent to the landing; nothing is written" do
    get settings_path(locale: :en)
    assert_redirected_to home_path(locale: :en)
    assert_nil flash[:alert]

    patch settings_path(locale: :en), params: { reduced_motion: "on" }
    assert_redirected_to home_path(locale: :en)
    assert_nil cookies[:motion]
    assert_nil @player.reload.reduced_motion
  end

  test "reading the settings writes nothing: no cookie, no setting" do
    sign_in(@player)

    get settings_path(locale: :en)

    assert_not_includes Array(response.headers["Set-Cookie"]).join("\n"), "motion="
    assert_nil @player.reload.reduced_motion
  end

  # The profile visibility row

  %w[private friends_only public].each do |choice|
    test "choosing #{choice} stores it at once and marks it" do
      @player.update!(visibility: "private") if choice == "public"
      sign_in(@player)

      patch settings_visibility_path(locale: :en), params: { visibility: choice }

      assert_redirected_to settings_path(locale: :en)
      assert_response :see_other
      assert_equal choice, @player.reload.visibility
      follow_redirect!
      assert_select "button[name=visibility][value=#{choice}][aria-pressed=true]", 1
      assert_select "button[name=visibility][aria-pressed=true]", 1
    end
  end

  test "PRIVÉ posted with trades open but unconfirmed changes nothing and comes back with the dialog open" do
    open_trade(proposer: @player, recipient: accounts_players(:moderator))
    sign_in(@player)

    patch settings_visibility_path(locale: :fr), params: { visibility: "private" }

    assert_redirected_to settings_path(locale: :fr)
    assert_equal "public", @player.reload.visibility
    assert_equal "open", Game::Trade.sole.status
    follow_redirect!
    assert_select "dialog#private-dialog[open]" do
      assert_select ".private-dialog__text", "Passer en privé annule votre échange en cours."
      assert_select "input[type=hidden][name=confirmed_trades][value=1]"
    end
    assert_nil flash[:notice]

    get settings_path(locale: :fr)
    assert_select "dialog#private-dialog:not([open])"
  end

  test "a trade opened since the page loaded brings the dialog back with the new count, and confirming it cancels both" do
    open_trade(proposer: @player, recipient: accounts_players(:moderator))
    sign_in(@player)

    get settings_path(locale: :fr)
    assert_select "dialog#private-dialog:not([open]) input[name=confirmed_trades][value=1]"

    open_trade(proposer: accounts_players(:administrator), recipient: @player)
    patch settings_visibility_path(locale: :fr), params: { visibility: "private", confirmed_trades: "1" }

    assert_equal "public", @player.reload.visibility
    follow_redirect!
    assert_select "dialog#private-dialog[open]" do
      assert_select ".private-dialog__text", "Passer en privé annule vos 2 échanges en cours."
      assert_select "input[type=hidden][name=confirmed_trades][value=2]"
    end

    patch settings_visibility_path(locale: :fr), params: { visibility: "private", confirmed_trades: "2" }

    assert_redirected_to settings_path(locale: :fr)
    assert_equal "private", @player.reload.visibility
    assert_equal [ "cancelled", "cancelled" ], Game::Trade.order(:created_at).pluck(:status)
    assert_nil flash[:notice]
    follow_redirect!
    assert_select "dialog#private-dialog", 0
  end

  test "PRIVÉ posted again by a private player with trades open applies at once, without the dialog" do
    open_trade(proposer: @player, recipient: accounts_players(:moderator))
    @player.update!(visibility: "private")
    sign_in(@player)

    patch settings_visibility_path(locale: :fr), params: { visibility: "private" }

    assert_redirected_to settings_path(locale: :fr)
    assert_equal "private", @player.reload.visibility
    follow_redirect!
    assert_select "dialog#private-dialog", 0
  end

  [ nil, "", "two", [ "1" ] ].each do |confirmed|
    test "a confirmed count of #{confirmed.inspect} confirms no trade" do
      open_trade(proposer: @player, recipient: accounts_players(:moderator))
      sign_in(@player)

      patch settings_visibility_path(locale: :en), params: { visibility: "private", confirmed_trades: confirmed }

      assert_equal "public", @player.reload.visibility
      assert_equal "open", Game::Trade.sole.status
    end
  end

  [ nil, "", "everyone", "Private", [ "private" ] ].each do |choice|
    test "#{choice.inspect} is no visibility: refused with its message, nothing changes" do
      sign_in(@player)

      patch settings_visibility_path(locale: :fr), params: { visibility: choice }

      assert_redirected_to settings_path(locale: :fr)
      assert_equal I18n.t("errors.accounts.invalid_setting", locale: :fr), flash[:alert]
      assert_equal "public", @player.reload.visibility
    end
  end

  test "with trades open, PRIVÉ first opens a dialog that says how many going private cancels" do
    bob = accounts_players(:moderator)
    Game::Friendship.create!(low_player_id: [ @player.id, bob.id ].min, high_player_id: [ @player.id, bob.id ].max)
    Game::Holding.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 1)
    Game::Holding.create!(player_id: bob.id, card_season_id: catalog_card_seasons(:rare_card_one).id, quantity: 1)
    Game::ProposeTrade.new.call(player: @player, recipient: bob, offer: { catalog_card_seasons(:portal_one).id => 1 },
      request: { catalog_card_seasons(:rare_card_one).id => 1 }).value!
    sign_in(@player)

    get settings_path(locale: :fr)

    assert_select "button[name=visibility][value=private][type=submit][aria-haspopup=dialog][data-dialog-opener-dialog-value=private-dialog]", "Privé"
    assert_select "button[name=visibility][value=friends_only]:not([data-dialog-opener-dialog-value])"
    assert_select "dialog#private-dialog button.modal__close[type=submit][form=private-dialog-form][formmethod=dialog][data-action='dialog#close']"
    assert_select "dialog#private-dialog form#private-dialog-form[action='/fr/settings/visibility'][data-turbo=false]" do
      assert_select "input[name=_method][value=patch]"
      assert_select "input[type=hidden][name=visibility][value=private]"
      assert_select "input[type=hidden][name=confirmed_trades][value=1]"
      assert_select ".private-dialog__text", "Passer en privé annule votre échange en cours."
      assert_select "button[type=submit]", "Passer en privé"
      assert_select "button[type=submit][formmethod=dialog][data-action='dialog#close']", "Annuler"
    end

    patch settings_visibility_path(locale: :fr), params: { visibility: "private", confirmed_trades: "1" }
    assert_equal "cancelled", Game::Trade.sole.status
    follow_redirect!
    assert_select "dialog#private-dialog", 0
    assert_select "button[name=visibility][value=private]:not([data-dialog-opener-dialog-value])"
  end

  test "with no trade open, PRIVÉ applies at once, without a dialog" do
    sign_in(@player)

    get settings_path(locale: :en)

    assert_select "button[name=visibility][value=private]:not([aria-haspopup])", "Private"
    assert_select "dialog#private-dialog", 0
  end

  test "a visitor cannot set a visibility, and a GET writes nothing" do
    patch settings_visibility_path(locale: :en), params: { visibility: "private" }
    assert_redirected_to home_path(locale: :en)
    assert_nil flash[:alert]
    assert_equal "public", @player.reload.visibility

    sign_in(@player)
    get settings_path(locale: :en, visibility: "private")
    assert_equal "public", @player.reload.visibility
  end

  # Writing a setting

  { "on" => [ true, "reduced" ], "off" => [ false, "full" ] }.each do |choice, (value, cookie)|
    test "choosing #{choice} stores #{value} on the player and mirrors it in the cookie" do
      sign_in(@player)

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
    sign_in(@player)
    cookies[:motion] = "reduced"

    patch settings_path(locale: :en), params: { reduced_motion: "system" }

    assert_redirected_to settings_path(locale: :en)
    assert_nil @player.reload.reduced_motion
    assert_predicate cookies[:motion], :blank?
  end

  [ nil, "", "yes", "true", "reduced", [ "on" ] ].each do |choice|
    test "#{choice.inspect} is no choice: refused with its message, nothing changes" do
      @player.update!(reduced_motion: true)
      sign_in(@player)

      patch settings_path(locale: :fr), params: { reduced_motion: choice }

      assert_redirected_to settings_path(locale: :fr)
      assert_equal I18n.t("errors.accounts.invalid_setting", locale: :fr), flash[:alert]
      assert_equal true, @player.reload.reduced_motion
      assert_nil cookies[:motion]
    end
  end

  test "a change is a PATCH: no GET writes it" do
    sign_in(@player)

    get settings_path(locale: :en, reduced_motion: "on")

    assert_nil @player.reload.reduced_motion
    assert_nil cookies[:motion]
  end

  # The one switch: setting, else cookie, else system

  test "by default nothing is forced: no data-motion, and the view-transition meta renders" do
    sign_in(@player)

    get home_path(locale: :en)

    assert_nil forced_motion
    assert transition_meta?
  end

  test "a player's reduced motion sets html[data-motion=reduced] and renders no view-transition meta, on every page" do
    @player.update!(reduced_motion: true)
    sign_in(@player)

    [ home_path(locale: :en), settings_path(locale: :en), booster_path(locale: :en), library_path(locale: :fr) ].each do |path|
      get path

      assert reduced?, path
      assert_not transition_meta?, path
    end
  end

  test "a player's explicit no forces full motion over the system's preference, view transitions included" do
    @player.update!(reduced_motion: false)
    sign_in(@player)

    [ home_path(locale: :en), settings_path(locale: :fr) ].each do |path|
      get path

      assert_equal "full", forced_motion, path
      assert transition_meta?, path
    end
  end

  test "a visitor follows the cookie: reduced, no meta" do
    cookies[:motion] = "reduced"

    get home_path(locale: :en)

    assert_equal "reduced", forced_motion
    assert_not transition_meta?
  end

  test "a visitor with an explicit-no cookie is forced full motion" do
    cookies[:motion] = "full"

    get home_path(locale: :en)

    assert_equal "full", forced_motion
    assert transition_meta?
  end

  test "a visitor with no cookie, or a junk one, is forced nothing" do
    [ nil, "", "reduced ", "1", "Full" ].each do |value|
      cookies[:motion] = value
      get home_path(locale: :en)

      assert_nil forced_motion, value.inspect
      assert transition_meta?, value.inspect
    end
  end

  test "the player's setting wins over a cookie that says otherwise" do
    @player.update!(reduced_motion: false)
    sign_in(@player)
    cookies[:motion] = "reduced"

    get home_path(locale: :en)

    assert_equal "full", forced_motion

    @player.update!(reduced_motion: true)
    cookies[:motion] = "full"
    get home_path(locale: :en)

    assert_equal "reduced", forced_motion
  end

  test "a signed-in player who follows the system ignores the cookie" do
    sign_in(@player)

    [ "reduced", "full" ].each do |value|
      cookies[:motion] = value
      get home_path(locale: :en)

      assert_nil forced_motion, value
      assert transition_meta?, value
    end
  end

  test "the public pages and the signed-out card page follow the cookie too" do
    cookies[:motion] = "reduced"

    get brother_path(token: @player.token, locale: :en)

    assert reduced?
    assert_not transition_meta?
  end

  # Sign-out keeps the preference

  test "signing out writes the player's setting to the cookie, and the landing follows it" do
    @player.update!(reduced_motion: true)
    sign_in(@player)

    delete session_path(locale: :en)

    assert_equal "reduced", cookies[:motion]
    follow_redirect!
    assert_select ".landing-hero"
    assert reduced?
    assert_not transition_meta?
  end

  test "signing out with an explicit no keeps it as a cookie; with the system, removes the cookie" do
    @player.update!(reduced_motion: false)
    sign_in(@player)
    delete session_path(locale: :en)
    assert_equal "full", cookies[:motion]
    follow_redirect!
    assert_equal "full", forced_motion

    @player.update!(reduced_motion: nil)
    sign_in(@player)
    cookies[:motion] = "reduced"
    delete session_path(locale: :en)

    assert_predicate cookies[:motion], :blank?
    follow_redirect!
    assert_nil forced_motion
  end

  test "the own profile's gear leads to the settings, and the tab bar's PLUS opens the rest of the ship" do
    sign_in(@player)

    get brother_path(locale: :en, token: @player.token)

    assert_select ".profile-band a.profile-band__settings[href='/en/settings'][aria-label=?]", "Settings" do
      assert_select "svg.pixel-icon"
    end
    assert_select "a.tab-bar__tab[href='/en/more']", /More/
  end

  test "another player's profile shows no gear and no pen" do
    sign_in(accounts_players(:moderator))

    get brother_path(locale: :en, token: @player.token)

    assert_select ".profile-band__settings", false
    assert_select ".profile-pen", false
    assert_select "dialog.profile-edit", false
  end

  test "the PLUS screen lists the screens that are not tabs, and no longer the settings" do
    sign_in(@player)

    get more_path(locale: :fr)

    assert_response :success
    assert_select "main h1", "Pont de commandement"
    assert_select ".hub__subtitle", "Le reste du vaisseau"
    assert_select ".plus__list > li", 6
    assert_select ".plus__list > li:first-child a.menu-item.menu-item--plus[href='/fr/library/cards']", "Toutes les cartes"
    assert_select ".plus__list a.menu-item[href='/fr/settings']", false
    assert_select ".plus__list a.menu-item[href='/fr/personalization']", false
    assert_select ".plus__list > li:last-child a.menu-item[href='https://buymeacoffee.com/theiereman'][target=_blank]", "Soutenir (nouvel onglet)" do
      assert_select "svg.menu-item__external"
    end
    assert_select ".plus__list a.menu-item[href='/fr/how-it-works']", /Comment ça marche/
    assert_select ".plus__list a.menu-item[href='/fr/friends']", /Amis/
    assert_select ".plus__list a.menu-item[href='/fr/feed']", /Fil d'activité/
    assert_select ".plus__list a.menu-item[href='/fr/achievements']", /Succès/
    assert_select ".plus__list .menu-item[aria-disabled]", false
    assert_select "a.tab-bar__tab[href='/fr/more'][aria-current=page]"
  end

  test "the settings screen belongs to the own profile: no tab is current and the phone back leads to the profile" do
    sign_in(@player)

    get settings_path(locale: :fr)

    assert_select "a.tab-bar__tab[aria-current]", false
    assert_select ".top-bar a.top-bar__phone-back[href=?]", "/fr/brothers/#{@player.token}", text: /Profil/
  end

  test "staff reach the back-office from a row of the settings, players do not" do
    sign_in(@player)
    get settings_path(locale: :en)
    assert_select "#settings-back-office", false

    sign_in(accounts_players(:moderator))
    get settings_path(locale: :fr)
    assert_select "li.settings-row #settings-back-office", "Équipe"
    assert_select "li.settings-row a.button[href='/fr/back-office']", "Back-office"
  end

  test "the hub tab is current on the hub only" do
    sign_in(@player)

    get more_path(locale: :en)

    assert_select "a.tab-bar__tab[href='/en'][aria-current]", false
  end
end

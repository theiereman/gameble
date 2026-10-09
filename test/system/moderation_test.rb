require "application_system_test_case"

# A moderator works the queue of reported players: a ban keeps the player
# from signing in and hides their profile from players; lifting it gives
# both back. Staff still read a banned player's profile.
class ModerationTest < ApplicationSystemTestCase
  setup do
    OmniAuth.config.test_mode = true
    @moderator = accounts_players(:moderator)
    @reported = accounts_players(:player)
    @reported.update!(persona_name: "Gabe the Rude")
    reporters = (1..2).map { Accounts::Player.create!(steam_id: "7656119796039000#{it}") }
    Accounts::Report.create!(reporter: reporters[0], reported: @reported, reason: "inappropriate_name")
    Accounts::Report.create!(reporter: reporters[1], reported: @reported, reason: "harassment")
    Accounts::Report.create!(reporter: reporters[0], reported: accounts_players(:administrator), reason: "other")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def steam_identity(player)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
  end

  def row(player) = "tr[data-player-token='#{player.token}']"

  def sign_in_as_the_reported_player
    visit home_path(locale: :fr)
    steam_identity(@reported)
    click_steam_sign_in
  end

  test "a moderator bans a reported player from the queue, then lifts the ban" do
    steam_identity(@moderator)
    visit home_path(locale: :fr)
    click_steam_sign_in
    assert_signed_in

    visit back_office_path(locale: :fr)
    assert_text "2 joueurs signalés attendent les officiers."
    click_on "Les signalements"
    assert_selector "h1", text: "Les signalements"
    assert_selector "#{row(accounts_players(:administrator))} [data-ban-refusal=outranked]"
    assert_no_selector "#{row(accounts_players(:administrator))} button", text: "BANNIR"
    within(row(@reported)) do
      assert_selector "td[data-report-total='2']"
      accept_confirm { click_on "BANNIR" }
    end

    assert_text "Gabe the Rude est banni."
    assert_no_selector row(@reported)
    assert_predicate @reported.reload, :banned?

    using_session("reported") do
      sign_in_as_the_reported_player
      assert_text I18n.t("errors.accounts.banned", locale: :fr)
      assert_signed_out

      visit brother_path(locale: :fr, token: @reported.token)
      assert_selector "h1", text: "Profil indisponible"
    end

    click_on "Les bannis"
    assert_selector "h1", text: "Les bannis"
    within(row(@reported)) do
      accept_confirm { click_on "LEVER LE BAN" }
    end

    assert_text "Le ban de Gabe the Rude est levé."
    assert_no_selector row(@reported)

    using_session("reported") do
      sign_in_as_the_reported_player
      assert_signed_in

      visit brother_path(locale: :fr, token: @reported.token)
      assert_selector "h1", text: "Gabe the Rude"
    end
  end

  test "a moderator opens a banned player's profile from the banned list; a visitor finds it unavailable" do
    Accounts::BanPlayer.new.call(staff: accounts_players(:administrator), player: @reported).value!
    steam_identity(@moderator)
    visit home_path(locale: :fr)
    click_steam_sign_in
    assert_signed_in

    visit back_office_bans_path(locale: :fr)
    within(row(@reported)) { click_on "Gabe the Rude" }

    assert_selector "h1", text: "Gabe the Rude"
    assert_current_path brother_path(locale: :fr, token: @reported.token)

    using_session("visitor") do
      visit brother_path(locale: :fr, token: @reported.token)
      assert_selector "h1", text: "Profil indisponible"
    end
  end
end

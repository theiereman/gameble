require "application_system_test_case"
require_relative "../support/steam_sign_in"

# A moderator works the queue of reported players: a ban keeps the player
# from signing in and hides their profile from players; lifting it gives
# both back. Staff still read a banned player's profile.
class ModerationTest < ApplicationSystemTestCase
  include SteamSignIn

  setup do
    @moderator = accounts_players(:moderator)
    @reported = accounts_players(:player)
    @reported.update!(persona_name: "Gabe the Rude")
    reporters = (1..2).map { Accounts::Player.create!(steam_id: "7656119796039000#{it}") }
    Accounts::Report.create!(reporter: reporters[0], reported: @reported, reason: "inappropriate_name")
    Accounts::Report.create!(reporter: reporters[1], reported: @reported, reason: "harassment")
    Accounts::Report.create!(reporter: reporters[0], reported: accounts_players(:administrator), reason: "other")
  end

  def steam_identity(player)
    mock_steam_sign_in(player.steam_id)
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
      fill_in "reason", with: "Insults in the name"
      accept_confirm { click_on "BANNIR" }
    end

    assert_text "Gabe the Rude est banni."
    assert_no_selector row(@reported)
    assert_predicate @reported.reload, :banned?

    using_session("reported") do
      sign_in_as_the_reported_player
      assert_selector "h1", text: "Compte suspendu"
      assert_text I18n.t("errors.accounts.banned", locale: :fr)
      assert_selector ".account-suspended__reason", text: "Insults in the name"
      assert_text(/Pour contester cette décision, écrivez à .+\./)
      assert_signed_out

      visit brother_path(locale: :fr, token: @reported.token)
      assert_selector "h1", text: /\AProfil indisponible\z/i
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

  test "a moderator finds a player by part of the name or the Steam id and bans them from the list" do
    steam_identity(@moderator)
    visit home_path(locale: :fr)
    click_steam_sign_in
    assert_signed_in

    visit back_office_path(locale: :fr)
    click_on "Les joueurs"
    assert_selector "h1", text: "Les joueurs"
    within(row(accounts_players(:administrator))) do
      assert_selector "[data-ban-refusal=outranked]"
      assert_no_selector "button", text: "BANNIR"
    end

    fill_in "Chercher un joueur", with: "the rude"
    click_on "Chercher"
    assert_selector "tbody tr", count: 1
    within(row(@reported)) do
      assert_selector "td[data-player-state=good_standing]"
      fill_in "reason", with: "Insults in the name"
      accept_confirm { click_on "BANNIR" }
    end

    assert_text "Gabe the Rude est banni."
    assert_field "Chercher un joueur", with: "the rude"
    within(row(@reported)) do
      assert_selector "td[data-player-state=banned]", text: "Banni"
      assert_selector "button", text: "LEVER LE BAN"
    end
    assert_predicate @reported.reload, :banned?

    fill_in "Chercher un joueur", with: accounts_players(:administrator).steam_id
    click_on "Chercher"
    assert_selector "tbody tr", count: 1
    assert_selector row(accounts_players(:administrator))
  end

  test "a moderator opens a banned player's profile from the banned list; a visitor finds it unavailable" do
    Accounts::BanPlayer.new.call(staff: accounts_players(:administrator), player: @reported, reason: "Rude name").value!
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
      assert_selector "h1", text: /\AProfil indisponible\z/i
    end
  end

  test "a moderator bans with a reason, lifts the ban, classes reports, then reads it all in the history" do
    pester = Accounts::Player.create!(steam_id: "76561197960390101", persona_name: "Pester")
    Accounts::Report.create!(reporter: @reported, reported: pester, reason: "cheating")
    @moderator.update!(persona_name: "Officer Kim")
    steam_identity(@moderator)
    visit home_path(locale: :fr)
    click_steam_sign_in
    assert_signed_in

    visit back_office_reports_path(locale: :fr)
    within(row(@reported)) do
      click_on "BANNIR"
      assert_selector "input[name=reason]:invalid"
    end
    assert_selector row(@reported)
    assert_not @reported.reload.banned?

    within(row(@reported)) do
      fill_in "reason", with: "Insults in the name"
      accept_confirm { click_on "BANNIR" }
    end
    assert_text "Gabe the Rude est banni."

    within(row(pester)) do
      accept_confirm { click_on "CLASSER" }
    end
    assert_text "Les signalements de Pester sont classés."

    click_on "Les bannis"
    within(row(@reported)) do
      accept_confirm { click_on "LEVER LE BAN" }
    end
    assert_text "Le ban de Gabe the Rude est levé."

    visit back_office_path(locale: :fr)
    click_on "L'historique"
    assert_selector "h1", text: "L'historique de modération"
    assert_selector "tbody tr", count: 3
    within("tbody tr:nth-child(1)") do
      assert_selector "[data-moderation-player]", text: "Gabe the Rude"
      assert_text "Ban levé"
      assert_selector "[data-moderation-staff]", text: "Officer Kim"
      assert_selector "time"
    end
    within("tbody tr:nth-child(2)") do
      assert_selector "[data-moderation-player]", text: "Pester"
      assert_text "Signalements classés"
      assert_selector "[data-moderation-staff]", text: "Officer Kim"
      assert_selector "time"
    end
    within("tbody tr:nth-child(3)") do
      assert_selector "[data-moderation-player]", text: "Gabe the Rude"
      assert_text "Bannissement"
      assert_selector "[data-moderation-staff]", text: "Officer Kim"
      assert_selector "time"
      assert_selector "[data-moderation-reason]", text: "Insults in the name"
    end

    visit back_office_players_path(locale: :fr)
    within(row(pester)) { click_on "Historique" }
    assert_selector "h1", text: "L'historique de Pester"
    assert_selector "tbody tr", count: 1
    assert_selector "tbody tr[data-moderation-kind=dismissal]"
    click_on "Tout l'historique"
    assert_selector "tbody tr", count: 3
  end

  test "an administrator erases a banned player after the confirmation naming them, then finds the erasure in the history" do
    banned = accounts_players(:banned)
    banned.update!(persona_name: "Exile")
    steam_identity(accounts_players(:administrator))
    visit home_path(locale: :fr)
    click_steam_sign_in
    assert_signed_in

    visit back_office_players_path(locale: :fr)
    fill_in "Chercher un joueur", with: "exile"
    click_on "Chercher"
    within(row(banned)) do
      message = accept_confirm { click_on "EFFACER" }
      assert_includes message, "Exile"
    end

    assert_text "Le compte de Exile est effacé."
    assert_no_selector row(banned)
    assert_predicate banned.reload, :deleted?
    click_on "L'historique"
    assert_selector "tbody tr[data-moderation-kind=erasure]", text: "Compte effacé"
  end
end

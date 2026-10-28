require "test_helper"
require_relative "../../support/counting_rate_limit"
require_relative "../../support/hidden_back_office"
require_relative "../../support/steam_sign_in"

module BackOffice
  class PlayersControllerTest < ActionDispatch::IntegrationTest
    include CountingRateLimit
    include HiddenBackOffice
    include SteamSignIn

    def sign_in_origin = "/fr"

    setup do
      @target = accounts_players(:player)
      @target.update!(persona_name: "Gabe the Rude", visibility: :friends_only)
      @moderator = accounts_players(:moderator)
      @administrator = accounts_players(:administrator)
      @banned = accounts_players(:banned)
      @banned.update!(persona_name: "Exile")
    end

    def row(player) = "tr[data-player-token='#{player.token}']"

    test "a moderator reads every player: name, role, visibility, standing and the action or its refusal" do
      sign_in(@moderator)

      get back_office_players_path(locale: :fr)

      assert_response :success
      assert_select "h1", "Les joueurs"
      assert_select "form.ledger-search[method=get][action='/fr/back-office/players'] input[type=search][name=q]"
      assert_select "tbody tr", Accounts::Player.where(deleted_at: nil).count
      assert_select "#{row(@target)} a[href='/fr/brothers/#{@target.token}']", "Gabe the Rude"
      assert_select "#{row(@target)} td[data-player-role=player]", "Joueur"
      assert_select "#{row(@target)} td[data-player-visibility=friends_only]", "Amis uniquement"
      assert_select "#{row(@target)} td[data-player-state=good_standing]", "En règle"
      assert_select "#{row(@target)} form[action='/fr/back-office/bans'][method=post][data-turbo-confirm]" do
        assert_select "input[type=hidden][name=token][value='#{@target.token}']"
        assert_select "input[type=hidden][name=return_to][value=players]"
        assert_select "button.button--danger", "BANNIR"
      end
      assert_select "#{row(@banned)} td[data-player-state=banned]", "Banni"
      assert_select "#{row(@banned)} form[action='/fr/back-office/bans/#{@banned.token}'][data-turbo-confirm]" do
        assert_select "input[name=_method][value=delete]"
        assert_select "button", "LEVER LE BAN"
      end
      assert_select "#{row(@target)} td[data-player-history] a[href=?]", "/fr/back-office/history?player=#{@target.token}", "Historique"
      assert_select "#{row(@banned)} td[data-player-history] a[href=?]", "/fr/back-office/history?player=#{@banned.token}", "Historique"
      assert_select "#{row(@administrator)} td[data-player-role=administrator]", "Administrateur"
      assert_select "#{row(@administrator)} form", false
      assert_select "#{row(@administrator)} [data-ban-refusal=outranked]", I18n.t("errors.accounts.outranked", locale: :fr)
      assert_select "#{row(@moderator)} form", false
      assert_select "#{row(@moderator)} [data-ban-refusal=cannot_ban_self]"
      [ @target, @banned, @moderator, @administrator ].each do |player|
        assert_not_includes response.body, player.id.to_s
        assert_not_includes response.body, player.steam_id
      end
    end

    test "a moderator sees the refusal on another moderator's row; an administrator sees BANNIR there" do
      other_moderator = Accounts::Player.create!(steam_id: "76561197960380001", role: :moderator, persona_name: "Deputy")
      sign_in(@moderator)

      get back_office_players_path(locale: :fr, q: "deputy")

      assert_select "tbody tr", 1
      assert_select "#{row(other_moderator)} form", false
      assert_select "#{row(other_moderator)} [data-ban-refusal=outranked]"

      sign_in(@administrator)
      get back_office_players_path(locale: :fr, q: "deputy")

      assert_select "#{row(other_moderator)} button", "BANNIR"
      assert_select "#{row(@administrator)}", false
    end

    test "a search by part of a name or by a full Steam id narrows the list" do
      sign_in(@moderator)

      get back_office_players_path(locale: :fr, q: "  rUDE ")

      assert_select "tbody tr", 1
      assert_select row(@target)
      assert_select "input[name=q][value='rUDE']"

      get back_office_players_path(locale: :fr, q: @banned.steam_id)

      assert_select "tbody tr", 1
      assert_select row(@banned)
    end

    test "a query holding a NUL byte or a no-break space is cleaned before it is searched" do
      sign_in(@moderator)

      get back_office_players_path(locale: :fr), params: { q: "\u0000" }
      assert_response :success

      get back_office_players_path(locale: :fr), params: { q: "Gabe the\u0000  Rude" }
      assert_response :success
      assert_select "tbody tr", 1
      assert_select row(@target)
    end

    test "a search that matches no one says so, naming the query" do
      sign_in(@moderator)

      get back_office_players_path(locale: :fr, q: "nobody<b>")

      assert_select "tbody", false
      assert_select "main .panel[data-player-search-empty]", "Aucun joueur ne correspond à « nobody<b> »."
    end

    test "a deleted account is not listed, even searched by its old name" do
      deleted = Accounts::Player.create!(steam_id: "76561197960380002", persona_name: "Ghost")
      token = deleted.token
      Accounts::DeletePlayer.new.call(player: deleted).value!
      sign_in(@moderator)

      get back_office_players_path(locale: :fr)
      assert_not_includes response.body, deleted.reload.token
      assert_not_includes response.body, token

      get back_office_players_path(locale: :fr, q: "Ghost")
      assert_select "tbody", false
    end

    test "a ban from a searched list comes back to it, the row banned and offering LEVER LE BAN" do
      sign_in(@moderator)

      post back_office_bans_path(locale: :fr), params: { token: @target.token, return_to: "players", q: "rude", page: "2", reason: "Rude name" }

      assert_redirected_to back_office_players_path(locale: :fr, q: "rude", page: 2)
      assert_equal "Gabe the Rude est banni.", flash[:notice]
      assert_predicate @target.reload, :banned?

      get back_office_players_path(locale: :fr, q: "rude")

      assert_select "#{row(@target)} td[data-player-state=banned]", "Banni"
      assert_select "#{row(@target)} form" do
        assert_select "input[name=_method][value=delete]"
        assert_select "input[type=hidden][name=q][value=rude]"
        assert_select "button", "LEVER LE BAN"
      end
    end

    test "lifting a ban from the list comes back to it with the search" do
      sign_in(@moderator)

      delete back_office_ban_path(locale: :fr, token: @banned.token), params: { return_to: "players", q: "exile" }

      assert_redirected_to back_office_players_path(locale: :fr, q: "exile")
      assert_equal "Le ban de Exile est levé.", flash[:notice]
      follow_redirect!
      assert_select "#{row(@banned)} td[data-player-state=good_standing]"
      assert_select "#{row(@banned)} button", "BANNIR"
    end

    test "a refusal from the list comes back to it with the alert" do
      sign_in(@moderator)

      post back_office_bans_path(locale: :fr), params: { token: @administrator.token, return_to: "players", q: "x", reason: "Rude name" }

      assert_redirected_to back_office_players_path(locale: :fr, q: "x")
      assert_equal I18n.t("errors.accounts.outranked", locale: :fr), flash[:alert]
      assert_not @administrator.reload.banned?

      delete back_office_ban_path(locale: :fr, token: @target.token), params: { return_to: "players" }

      assert_redirected_to back_office_players_path(locale: :fr)
      assert_equal I18n.t("errors.accounts.not_banned", locale: :fr), flash[:alert]
    end

    test "any other return name leaves the queue's and the banned list's redirects as they are" do
      sign_in(@moderator)

      post back_office_bans_path(locale: :fr), params: { token: @target.token, return_to: "https://example.com", reason: "Rude name" }
      assert_redirected_to back_office_reports_path(locale: :fr)

      delete back_office_ban_path(locale: :fr, token: @target.token), params: { return_to: "/fr/back-office/players" }
      assert_redirected_to back_office_bans_path(locale: :fr)
    end

    test "the second page holds the 51st player, the oldest account, and keeps the search" do
      Accounts::Player.update_all(created_at: 1.week.ago)
      oldest = Accounts::Player.create!(steam_id: "76561197960381000", persona_name: "Bulk oldest", created_at: 1.day.ago)
      50.times do |index|
        Accounts::Player.create!(steam_id: "765611979603810#{(index + 1).to_s.rjust(2, "0")}", persona_name: "Bulk #{index}",
          created_at: (index + 1).minutes.ago)
      end
      sign_in(@moderator)

      get back_office_players_path(locale: :fr, q: "bulk")
      assert_select "tbody tr", 50
      assert_select row(oldest), false
      assert_select "a[href='/fr/back-office/players?q=bulk&page=2']"

      get back_office_players_path(locale: :fr, q: "bulk", page: 2)

      assert_response :success
      assert_select "tbody tr", 1
      assert_select row(oldest) do
        assert_select "input[type=hidden][name=page][value='2']"
      end
    end

    test "an administrator reads the players in English" do
      sign_in(@administrator)

      get back_office_players_path(locale: :en, q: "gabe")

      assert_select "h1", "The players"
      assert_select "#{row(@target)} td[data-player-role=player]", "Player"
      assert_select "#{row(@target)} td[data-player-visibility=friends_only]", "Friends only"
      assert_select "#{row(@target)} td[data-player-state=good_standing]", "In good standing"
      assert_select "#{row(@target)} button", "BAN"

      get back_office_players_path(locale: :en, q: "nobody")
      assert_select "main .panel[data-player-search-empty]", "No player matches “nobody”."
    end

    test "the dashboard links to the players first" do
      sign_in(@moderator)

      get back_office_path(locale: :fr)

      assert_select "main a[href='/fr/back-office/players']", "Les joueurs"
    end

    test "a player and a visitor get the 404 of an unknown address" do
      get back_office_players_path(locale: :fr)
      assert_unknown_address

      sign_in(@target)
      get back_office_players_path(locale: :fr, q: "gabe")
      assert_unknown_address
    end

    test "an administrator sees ÉFFACER on a banned player's row only; a moderator never does" do
      sign_in(@administrator)

      get back_office_players_path(locale: :fr)

      assert_select "#{row(@banned)} form[action='/fr/back-office/players/#{@banned.token}'][data-turbo-confirm]" do
        assert_select "input[name=_method][value=delete]"
        assert_select "button.button--danger", "EFFACER"
      end
      assert_select "#{row(@target)} form[action='/fr/back-office/players/#{@target.token}']", false
      assert_select "#{row(@administrator)} form[action='/fr/back-office/players/#{@administrator.token}']", false

      sign_in(@moderator)
      get back_office_players_path(locale: :fr)

      assert_select "#{row(@banned)} form[action='/fr/back-office/players/#{@banned.token}']", false
    end

    test "an administrator erases a banned player from the list and comes back to it with the search" do
      sign_in(@administrator)

      delete back_office_player_path(locale: :fr, token: @banned.token), params: { q: "exile", page: "2" }

      assert_redirected_to back_office_players_path(locale: :fr, q: "exile", page: 2)
      assert_equal "Le compte de Exile est effacé.", flash[:notice]
      assert_predicate @banned.reload, :deleted?
      assert_predicate @banned, :banned?
      assert_equal "erasure", Accounts::ModerationAction.where(player: @banned).order(:id).last.kind
      get back_office_players_path(locale: :fr, q: "exile")
      assert_select row(@banned), false
    end

    test "the history lists the erasure under the erased account's deleted name" do
      sign_in(@administrator)
      delete back_office_player_path(locale: :fr, token: @banned.token)

      get back_office_history_path(locale: :fr)

      assert_select "tr[data-moderation-kind=erasure] td", text: "Compte effacé"
      assert_select "tr[data-moderation-kind=erasure] td[data-moderation-player]", "Compte supprimé"
    end

    test "a moderator cannot erase: the page is forbidden and the account stays" do
      sign_in(@moderator)

      delete back_office_player_path(locale: :fr, token: @banned.token)

      assert_response :forbidden
      assert_not_predicate @banned.reload, :deleted?
    end

    test "a player and a visitor cannot erase" do
      delete back_office_player_path(locale: :fr, token: @banned.token)
      assert_unknown_address

      sign_in(@target)
      delete back_office_player_path(locale: :fr, token: @banned.token)
      assert_unknown_address
      assert_not_predicate @banned.reload, :deleted?
    end

    test "erasing a player in good standing comes back to the list with the alert" do
      sign_in(@administrator)

      delete back_office_player_path(locale: :fr, token: @target.token)

      assert_redirected_to back_office_players_path(locale: :fr)
      assert_equal I18n.t("errors.accounts.not_banned", locale: :fr), flash[:alert]
      assert_not_predicate @target.reload, :deleted?
    end

    test "erasing is rate limited like banning" do
      sign_in(@administrator)

      with_counting_rate_limit(BackOffice::PlayersController) do
        30.times { delete back_office_player_path(locale: :fr, token: @target.token) }
        delete back_office_player_path(locale: :fr, token: @target.token)
      end

      assert_response :too_many_requests
    end
  end
end

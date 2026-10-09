require "test_helper"
require_relative "../../support/counting_rate_limit"
require_relative "../../support/hidden_back_office"

module BackOffice
  class BansControllerTest < ActionDispatch::IntegrationTest
    include CountingRateLimit
    include HiddenBackOffice

    setup do
      OmniAuth.config.test_mode = true
      @target = accounts_players(:player)
      @target.update!(persona_name: "Gabe")
      @moderator = accounts_players(:moderator)
      @administrator = accounts_players(:administrator)
      @banned = accounts_players(:banned)
      reporter = Accounts::Player.create!(steam_id: "76561197960360001")
      @report = Accounts::Report.create!(reporter:, reported: @target, reason: "cheating")
    end

    teardown do
      OmniAuth.config.mock_auth.delete(:steam)
      OmniAuth.config.test_mode = false
    end

    def sign_in(player)
      OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
      post "/auth/steam", params: { origin: "/fr" }
      follow_redirect!
      assert_equal player.id, session[:player_id]
    end

    def row(player) = "tr[data-player-token='#{player.token}']"

    test "a moderator bans a reported player: the player leaves the queue and joins the banned players" do
      sign_in(@moderator)

      post back_office_bans_path(locale: :fr), params: { token: @target.token, reason: "Rude name" }

      assert_redirected_to back_office_reports_path(locale: :fr)
      assert_equal I18n.t("back_office.bans.create.banned", name: "Gabe", locale: :fr), flash[:notice]
      assert_predicate @target.reload, :banned?
      assert_not_nil @report.reload.handled_at
      follow_redirect!
      assert_select row(@target), false

      get back_office_bans_path(locale: :fr)

      assert_response :success
      assert_select "h1", "Les bannis"
      assert_select "tbody tr:first-child[data-player-token='#{@target.token}'] td:first-child a[href='/fr/brothers/#{@target.token}']", "Gabe"
      assert_select row(@banned)
      assert_select "#{row(@target)} form[action='/fr/back-office/bans/#{@target.token}'][data-turbo-confirm]" do
        assert_select "input[name=_method][value=delete]"
        assert_select "button", "LEVER LE BAN"
      end
      [ @target, @banned, @moderator ].each { |player| assert_not_includes response.body, player.id.to_s }
    end

    test "a ban without a reason, or with an overlong one, is refused with the alert and the player stays unbanned" do
      sign_in(@moderator)

      [ {}, { reason: "" }, { reason: " \u200B\u3000 " } ].each do |reason|
        post back_office_bans_path(locale: :fr), params: { token: @target.token, **reason }

        assert_redirected_to back_office_reports_path(locale: :fr)
        assert_equal "Indiquez la raison du bannissement, officier.", flash[:alert]
      end
      post back_office_bans_path(locale: :fr), params: { token: @target.token, return_to: "players", reason: "a" * 501 }

      assert_redirected_to back_office_players_path(locale: :fr)
      assert_equal I18n.t("errors.accounts.reason_too_long", locale: :fr), flash[:alert]
      assert_not @target.reload.banned?
      assert_nil @report.reload.handled_at
      assert_equal 0, Accounts::ModerationAction.count
    end

    test "the ban keeps its cleaned reason in the history, never in the notice" do
      sign_in(@moderator)

      post back_office_bans_path(locale: :fr), params: { token: @target.token, reason: "  Insults\u200B in the name " }

      assert_equal "Gabe est banni.", flash[:notice]
      assert_equal [ [ "ban", @target, @moderator, "Insults in the name" ] ],
        Accounts::ModerationAction.all.map { [ it.kind, it.player, it.staff, it.reason ] }
    end

    test "the ban form asks for a reason, on the queue and on the players list; the lists link to the history" do
      sign_in(@moderator)

      [ back_office_reports_path(locale: :fr), back_office_players_path(locale: :fr) ].each do |path|
        get path

        assert_select "#{row(@target)} form.ban-form[action='/fr/back-office/bans'][method=post][data-turbo-confirm]" do
          assert_select "label.visually-hidden[for='ban-reason-#{@target.token}']", "Raison du bannissement de Gabe"
          assert_select "input#ban-reason-#{@target.token}[type=text][name=reason][required][maxlength='500'][autocomplete=off][placeholder='Raison du ban']"
          assert_select "button.button--danger[type=submit]", "BANNIR"
        end
        assert_select "a[href='/fr/back-office/history']", "L'historique"
      end

      get back_office_bans_path(locale: :fr)
      assert_select "form.ban-form", false
      assert_select "a[href='/fr/back-office/history']", "L'historique"
    end

    test "a moderator lifts a ban: the player leaves the banned players" do
      sign_in(@moderator)

      delete back_office_ban_path(locale: :fr, token: @banned.token)

      assert_redirected_to back_office_bans_path(locale: :fr)
      assert_match(/\ALe ban de Joueur \S+ est levé\.\z/, flash[:notice])
      assert_not @banned.reload.banned?
      follow_redirect!
      assert_select row(@banned), false
      assert_select "main .panel", I18n.t("back_office.bans.index.empty", locale: :fr)
    end

    test "the refusals come back as alerts and change nothing" do
      sign_in(@moderator)

      {
        @administrator.token => :outranked,
        @moderator.token => :cannot_ban_self,
        @banned.token => :already_banned,
        "A" * 24 => :player_not_found,
        "" => :player_not_found
      }.each do |token, code|
        post back_office_bans_path(locale: :fr), params: { token:, reason: "Rude name" }

        assert_redirected_to back_office_reports_path(locale: :fr)
        assert_equal I18n.t("errors.accounts.#{code}", locale: :fr), flash[:alert], code
      end
      assert_not @administrator.reload.banned?
      assert_not @moderator.reload.banned?

      delete back_office_ban_path(locale: :fr, token: @target.token)
      assert_redirected_to back_office_bans_path(locale: :fr)
      assert_equal I18n.t("errors.accounts.not_banned", locale: :fr), flash[:alert]
    end

    test "a banned moderator's row shows the refusal to a moderator and LIFT THE BAN to an administrator" do
      banned_moderator = Accounts::Player.create!(steam_id: "76561197960360099", role: :moderator, banned_at: 1.hour.ago)
      sign_in(@moderator)

      get back_office_bans_path(locale: :fr)

      assert_select "#{row(banned_moderator)} form", false
      assert_select "#{row(banned_moderator)} [data-unban-refusal=outranked]", I18n.t("errors.accounts.outranked", locale: :fr)
      assert_select "#{row(@banned)} button", "LEVER LE BAN"
      delete back_office_ban_path(locale: :fr, token: banned_moderator.token)
      assert_equal I18n.t("errors.accounts.outranked", locale: :fr), flash[:alert]
      assert_predicate banned_moderator.reload, :banned?

      sign_in(@administrator)
      get back_office_bans_path(locale: :en)

      assert_select "#{row(banned_moderator)} button", "LIFT THE BAN"
      delete back_office_ban_path(locale: :en, token: banned_moderator.token)
      assert_not banned_moderator.reload.banned?
    end

    test "a moderator opens a banned player's profile from the banned list" do
      @banned.update!(persona_name: "Exile")
      sign_in(@moderator)

      get back_office_bans_path(locale: :fr)
      assert_select "#{row(@banned)} a[href='/fr/brothers/#{@banned.token}']", "Exile"

      get brother_path(locale: :fr, token: @banned.token)
      assert_response :success
      assert_select "h1", "Exile"
    end

    test "an administrator bans and lifts a ban, in English" do
      sign_in(@administrator)

      post back_office_bans_path(locale: :en), params: { token: @target.token, reason: "Rude name" }
      assert_equal "Gabe is banned.", flash[:notice]

      get back_office_bans_path(locale: :en)
      assert_select "h1", "The banned players"

      delete back_office_ban_path(locale: :en, token: @target.token)
      assert_equal "The ban on Gabe is lifted.", flash[:notice]
      assert_not @target.reload.banned?
    end

    test "the second page of the banned players holds the 51st, the oldest ban" do
      50.times do |index|
        Accounts::Player.create!(steam_id: "765611979603620#{index.to_s.rjust(2, "0")}", banned_at: (index + 1).minutes.ago)
      end
      sign_in(@moderator)

      get back_office_bans_path(locale: :fr)
      assert_select "tbody tr", 50
      assert_select row(@banned), false
      assert_select "a[href='/fr/back-office/bans?page=2']"

      get back_office_bans_path(locale: :fr, page: 2)

      assert_response :success
      assert_select "tbody tr", 1
      assert_select row(@banned)
      assert_select "a[href='/fr/back-office/bans?page=1']"
    end

    test "more than 30 bans a minute are throttled" do
      sign_in(@moderator)

      with_counting_rate_limit(BansController) do
        30.times do
          post back_office_bans_path(locale: :fr), params: { token: @target.token, reason: "Rude name" }
          assert_redirected_to back_office_reports_path(locale: :fr)
        end

        post back_office_bans_path(locale: :fr), params: { token: @target.token, reason: "Rude name" }
      end

      assert_response :too_many_requests
    end

    test "a player gets the 404 of an unknown address from every action" do
      sign_in(@target)

      get back_office_bans_path(locale: :fr)
      assert_unknown_address
      post back_office_bans_path(locale: :fr), params: { token: @moderator.token, reason: "Rude name" }
      assert_unknown_address
      delete back_office_ban_path(locale: :fr, token: @banned.token)
      assert_unknown_address

      assert_not @moderator.reload.banned?
      assert_predicate @banned.reload, :banned?
    end

    test "a visitor gets the 404 of an unknown address from every action" do
      get back_office_bans_path(locale: :fr)
      assert_unknown_address
      post back_office_bans_path(locale: :fr), params: { token: @target.token, reason: "Rude name" }
      assert_unknown_address
      delete back_office_ban_path(locale: :fr, token: @banned.token)
      assert_unknown_address

      assert_not @target.reload.banned?
      assert_predicate @banned.reload, :banned?
    end
  end
end

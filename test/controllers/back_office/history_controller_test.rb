require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/steam_sign_in"

module BackOffice
  class HistoryControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include SteamSignIn

    def sign_in_origin = "/fr"

    setup do
      @target = accounts_players(:player)
      @target.update!(persona_name: "Gabe the Rude")
      @moderator = accounts_players(:moderator)
      @moderator.update!(persona_name: "Officer Kim")
      @administrator = accounts_players(:administrator)
      @banned = accounts_players(:banned)
      @banned.update!(persona_name: "Exile")
    end

    def action(kind, player, at, staff: @moderator, reason: nil)
      Accounts::ModerationAction.create!(kind:, player:, staff:, reason:, created_at: at)
    end

    def history_path(**params) = back_office_history_path(locale: :fr, **params)

    test "a moderator reads every action, the latest first: date, action, player, member of staff and reason" do
      action(:ban, @banned, Time.utc(2026, 10, 7, 9))
      action(:dismissal, @target, Time.utc(2026, 10, 8, 10), staff: @administrator)
      action(:ban, @target, Time.utc(2026, 10, 9, 11), reason: "<b>Insults</b> in the name")
      sign_in(@moderator)

      get history_path

      assert_response :success
      assert_select "h1", "L'historique de modération"
      assert_select "p", /Chaque ligne s'efface un an après sa fin, comme le dit la notice de confidentialité\./
      assert_select "p", text: /Rien ne s'efface/, count: 0
      assert_select "thead th", %w[Date Action Joueur Par Raison].size
      assert_select "tbody tr", 3
      assert_select "tbody tr:nth-child(1)[data-moderation-kind=ban]" do
        assert_select "td:first-child time[datetime='2026-10-09T11:00:00Z']", "2026-10-09 11:00:00 UTC"
        assert_select "td:nth-child(2)", "Bannissement"
        assert_select "td[data-moderation-player] a[href=?]", "/fr/back-office/history?player=#{@target.token}", "Gabe the Rude"
        assert_select "td[data-moderation-staff]", "Officer Kim"
        assert_select "td[data-moderation-reason]", "<b>Insults</b> in the name"
      end
      assert_select "tbody tr:nth-child(2)[data-moderation-kind=dismissal]" do
        assert_select "td:nth-child(2)", "Signalements classés"
        assert_select "td[data-moderation-reason]", "—"
      end
      assert_select "tbody tr:nth-child(3)[data-moderation-kind=ban] td[data-moderation-reason]", "Raison non consignée"
      assert_select "td[data-moderation-reason] b", false
      assert_includes response.body, "&lt;b&gt;Insults&lt;/b&gt;"
      [ @target, @banned, @moderator, @administrator ].each do |player|
        assert_not_includes response.body, player.id.to_s
        assert_not_includes response.body, player.steam_id
      end
    end

    test "a deleted account keeps its lines, named as deleted, with no link" do
      ghost = Accounts::Player.create!(steam_id: "76561197960396001", persona_name: "Ghost")
      former = Accounts::Player.create!(steam_id: "76561197960396002", role: :moderator, persona_name: "Former officer")
      action(:ban, ghost, 2.hours.ago, staff: former, reason: "Spam")
      action(:unban, @banned, 1.hour.ago, staff: former)
      Accounts::DeletePlayer.new.call(player: ghost).value!
      Accounts::DeletePlayer.new.call(player: former).value!
      sign_in(@moderator)

      get history_path

      assert_select "tbody tr", 2
      assert_select "tbody tr:nth-child(2) td[data-moderation-player]", "Compte supprimé"
      assert_select "tbody tr:nth-child(2) td[data-moderation-player] a", false
      assert_select "td[data-moderation-staff]", text: "Compte supprimé", count: 2
      assert_not_includes response.body, "Ghost"
      assert_not_includes response.body, ghost.reload.token
    end

    test "the history of one player, reached by token, lists only that player's lines" do
      action(:ban, @target, 2.hours.ago, reason: "Spam")
      action(:dismissal, @banned, 90.minutes.ago)
      action(:unban, @target, 1.hour.ago)
      sign_in(@moderator)

      get history_path(player: @target.token)

      assert_response :success
      assert_select "h1", "L'historique de Gabe the Rude"
      assert_select "tbody tr", 2
      assert_select "tbody tr:nth-child(1)[data-moderation-kind=unban]"
      assert_select "tbody tr:nth-child(2)[data-moderation-kind=ban]"
      assert_select "a[href='/fr/back-office/history']", "Tout l'historique"

      get history_path(player: @administrator.token)

      assert_select "tbody", false
      assert_select "main .panel[data-moderation-history-empty=player]", "Aucune action de modération ne concerne Joueur #{Accounts::PublicProfile.code(@administrator.token)}."
    end

    test "a token matching no account, or a deleted one, says the player is not found" do
      action(:ban, @target, 1.hour.ago, reason: "Spam")
      deleted = Accounts::Player.create!(steam_id: "76561197960396003")
      Accounts::DeletePlayer.new.call(player: deleted).value!
      sign_in(@moderator)

      [ "A" * 24, "<script>", deleted.reload.token ].each do |token|
        get history_path(player: token)

        assert_response :success
        assert_select "h1", "L'historique de modération"
        assert_select "tbody", false
        assert_select "main .panel[data-moderation-history-empty=unknown_player]", "Aucun joueur ne correspond à ce lien."
        assert_select "a[href='/fr/back-office/history']", "Tout l'historique"
      end

      get history_path(player: { token: @target.token })
      assert_select "main .panel[data-moderation-history-empty=unknown_player]"
    end

    test "an empty history says so" do
      sign_in(@moderator)

      get history_path

      assert_select "tbody", false
      assert_select "main .panel[data-moderation-history-empty=all]", "Aucune action de modération n'est encore consignée."
      assert_select "a[href='/fr/back-office/history']", false
    end

    test "the second page holds the 51st line, the oldest" do
      oldest = action(:ban, @banned, 2.days.ago, reason: "Oldest")
      50.times { |index| action(:dismissal, @target, (index + 1).minutes.ago) }
      sign_in(@moderator)

      get history_path
      assert_select "tbody tr", 50
      assert_select "tbody tr[data-moderation-kind=ban]", false
      assert_select "a[href=?]", "/fr/back-office/history?page=2"

      get history_path(page: 2)

      assert_response :success
      assert_select "tbody tr", 1
      assert_select "tbody tr[data-moderation-kind=ban] td[data-moderation-reason]", oldest.reason
    end

    test "an administrator reads the history in English" do
      action(:ban, @target, 2.hours.ago)
      action(:unban, @target, 1.hour.ago, staff: @administrator)
      sign_in(@administrator)

      get back_office_history_path(locale: :en)

      assert_select "h1", "The moderation history"
      assert_select "tbody tr:nth-child(1) td:nth-child(2)", "Ban lifted"
      assert_select "tbody tr:nth-child(2) td[data-moderation-reason]", "Reason not recorded"

      get back_office_history_path(locale: :en, player: @target.token)
      assert_select "h1", "The history of Gabe the Rude"
    end

    test "a player gets the 404 of an unknown address" do
      sign_in(@target)

      get history_path
      assert_unknown_address
      get history_path(player: @target.token)
      assert_unknown_address
    end

    test "a visitor gets the 404 of an unknown address" do
      get history_path

      assert_unknown_address
    end
  end
end

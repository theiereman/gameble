require "test_helper"
require_relative "../../support/counting_rate_limit"
require_relative "../../support/hidden_back_office"

module BackOffice
  # To whoever is not staff, every back-office address, Mission Control's
  # included, answers as an unknown address does, whatever the verb, before
  # the browser check, the forgery check, the rate limit and the policy.
  class HiddenTest < ActionDispatch::IntegrationTest
    include CountingRateLimit
    include HiddenBackOffice

    TOKEN = "A" * 24
    VERBS = %i[get head post patch put delete].freeze
    OLD_BROWSER = "Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko"

    def self.filled(spec) = spec.to_s.sub("(.:format)", "").gsub(":locale", "fr").gsub(/:\w+/, TOKEN)

    # Every back-office address the application routes, and every address of
    # the job queue's engine under its mount.
    def self.back_office_paths
      app = Rails.application.routes.routes.map { |route| route.path.spec.to_s }.select { it.include?("back-office") }
      engine = MissionControl::Jobs::Engine.routes.routes.map { |route| "/back-office/jobs#{route.path.spec}" }
      (app + engine).map { filled(it) }.uniq
    end

    setup do
      OmniAuth.config.test_mode = true
      @moderator = accounts_players(:moderator)
      @target = accounts_players(:player)
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

    def unknown_address_body
      get "/fr/back-office/nonexistent"
      assert_response :not_found
      response.body
    end

    def state = [ Accounts::Player.where.not(banned_at: nil).count, Accounts::Report.unhandled.count, Steam::ImportRun.count, Catalog::Season.count ]

    def with_forgery_protection
      allowed = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = allowed
    end

    test "the addresses tried include every back-office page, the job queue and its engine's pages" do
      paths = self.class.back_office_paths

      assert_includes paths, "/fr/back-office"
      assert_includes paths, "/fr/back-office/bans/#{TOKEN}"
      assert_includes paths, "/fr/back-office/import-runs/#{TOKEN}/resume"
      assert_includes paths, "/back-office/jobs/"
      assert_includes paths, "/back-office/jobs/queues"
      assert_includes paths, "/back-office/jobs/applications/#{TOKEN}/jobs/#{TOKEN}/retry"
    end

    { visitor: nil, player: :player }.each do |who, fixture|
      test "a #{who} gets the body of an unknown address from every back-office address, with every verb, and changes nothing" do
        Accounts::Report.create!(reporter: accounts_players(:administrator), reported: @target, reason: "cheating")
        unknown = unknown_address_body
        sign_in(accounts_players(fixture)) if fixture
        before = state

        self.class.back_office_paths.each do |path|
          VERBS.each do |verb|
            public_send(verb, path, params: { token: @target.token, number: 1 })

            assert_response :not_found, "#{verb} #{path}"
            assert_equal unknown, response.body, "#{verb} #{path}" unless verb == :head
          end
        end
        assert_equal before, state
      end
    end

    test "the 404 comes before the rate limit, which a player's requests do not consume" do
      sign_in(@target)

      with_counting_rate_limit(BansController) do
        31.times do
          post back_office_bans_path(locale: :fr), params: { token: @target.token }
          assert_unknown_address
        end

        sign_in(@moderator)
        post back_office_bans_path(locale: :fr), params: { token: @target.token }
      end

      assert_redirected_to back_office_reports_path(locale: :fr)
      assert_predicate @target.reload, :banned?
    end

    test "the 404 comes before the forgery check: a forged POST is a 404 for a visitor and a player, a 422 for staff" do
      with_forgery_protection do
        post back_office_bans_path(locale: :fr), params: { token: @target.token }
        assert_unknown_address
      end

      sign_in(@target)
      with_forgery_protection do
        post back_office_bans_path(locale: :fr), params: { token: @moderator.token }
        assert_unknown_address
        post "/back-office/jobs/applications/#{TOKEN}/jobs/bulk_retries"
        assert_unknown_address
      end

      sign_in(@moderator)
      with_forgery_protection do
        post back_office_bans_path(locale: :fr), params: { token: @target.token }
        assert_response :unprocessable_content
      end
      assert_not @target.reload.banned?
    end

    test "the 404 comes before the browser check: an old browser gets it as a visitor, staff get the unsupported-browser page" do
      get back_office_path(locale: :fr), headers: { "User-Agent" => OLD_BROWSER }
      assert_unknown_address

      sign_in(@moderator)
      get back_office_path(locale: :fr), headers: { "User-Agent" => OLD_BROWSER }
      assert_response :not_acceptable
    end

    test "a member of staff since banned or deleted gets the 404, signed out" do
      sign_in(@moderator)
      @moderator.update!(banned_at: Time.current)

      get back_office_path(locale: :fr)
      assert_unknown_address
      assert_nil session[:player_id]

      administrator = accounts_players(:administrator)
      sign_in(administrator)
      Accounts::DeletePlayer.new.call(player: administrator).value!

      get "/back-office/jobs"
      assert_unknown_address
      assert_nil session[:player_id]
    end

    test "staff keep reaching their pages; a moderator is refused an administrator's page with 403" do
      sign_in(@moderator)

      get back_office_path(locale: :fr)
      assert_response :success
      get back_office_seasons_path(locale: :fr)
      assert_response :forbidden
      get "/back-office/jobs"
      assert_response :forbidden
    end
  end
end

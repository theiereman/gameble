require "test_helper"
require_relative "../../support/catalog_seeds"

module BackOffice
  # The catalog seasons page of the back-office (AD-5), administrators only.
  class SeasonsControllerTest < ActionDispatch::IntegrationTest
    include CatalogSeeds

    setup { OmniAuth.config.test_mode = true }

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

    def tier_cells
      %w[gold amethyst sapphire emerald steel].map { |name| css_select("tr[data-season-number='2'] td[data-season-tier=#{name}]").first&.text }
    end

    test "an administrator sees the seasons and publishes the draft of 150 cards" do
      sign_in(accounts_players(:administrator))
      draft = seed_card_seasons(distinct_scores(150))

      get back_office_seasons_path(locale: :fr)

      assert_response :success
      assert_select "h1", "Les saisons du catalogue"
      assert_select "tr[data-season-number='1'][data-season-status=published] td[data-season-card-count='1']"
      assert_select "tr[data-season-number='1'] td[data-season-tier=amethyst]", "1"
      assert_select "tr[data-season-number='2'][data-season-status=draft] td", /Brouillon/
      assert_select "tr[data-season-number='2'] td[data-season-card-count='150']"
      assert_select "tr[data-season-number='2'] td[data-season-tier]", false
      assert_select "form[action='/fr/back-office/seasons/publish'][method=post][data-turbo-confirm]" do
        assert_select "input[type=hidden][name=number][value='2']"
        assert_select "button", "Publier la saison 2"
      end

      post publish_back_office_seasons_path(locale: :fr), params: { number: draft.number }

      assert_redirected_to back_office_seasons_path(locale: :fr)
      follow_redirect!
      assert_equal I18n.t("back_office.seasons.publish.published", number: 2, locale: :fr), flash[:notice]
      assert_select "tr[data-season-number='2'][data-season-status=published]"
      assert_equal %w[2 6 15 37 90], tier_cells
      assert_select "form[action$='/seasons/publish']", false

      by_tier = Catalog::PublishedCardSeasonsByTier.call
      assert_equal draft.id, by_tier[:season_id]
      assert_equal Catalog::CardSeason.where(season_id: draft.id).order(:id).ids, by_tier[:tiers].values.flatten.sort
    end

    test "publishing while a Steam import is active is refused" do
      sign_in(accounts_players(:administrator))
      draft = seed_card_seasons(distinct_scores(21))
      Steam::ImportRun.create!(status: :running, step: "app_list", started_at: 1.minute.ago)

      post publish_back_office_seasons_path(locale: :en), params: { number: draft.number }

      assert_redirected_to back_office_seasons_path(locale: :en)
      assert_equal I18n.t("back_office.seasons.publish.import_active", locale: :en), flash[:alert]
      assert_predicate draft.reload, :draft?
      assert_equal 0, Catalog::CardSeason.where(season_id: draft.id).where.not(rarity: nil).count
    end

    test "publishing while the latest Steam import has failed is refused, as it can still be resumed" do
      sign_in(accounts_players(:administrator))
      draft = seed_card_seasons(distinct_scores(21))
      Steam::ImportRun.create!(status: :completed, step: "reviews", created_at: 2.days.ago, finished_at: 2.days.ago)
      Steam::ImportRun.create!(status: :failed, step: "app_list", created_at: 1.hour.ago, finished_at: 1.minute.ago)

      post publish_back_office_seasons_path(locale: :en), params: { number: draft.number }

      assert_equal I18n.t("back_office.seasons.publish.import_active", locale: :en), flash[:alert]
      assert_predicate draft.reload, :draft?
    end

    test "an older failed run does not block publishing once the latest run completed" do
      sign_in(accounts_players(:administrator))
      draft = seed_card_seasons(distinct_scores(21))
      Steam::ImportRun.create!(status: :failed, step: "app_list", created_at: 2.days.ago, finished_at: 2.days.ago)
      Steam::ImportRun.create!(status: :completed, step: "reviews", created_at: 1.hour.ago, finished_at: 1.minute.ago)

      post publish_back_office_seasons_path(locale: :en), params: { number: draft.number }

      assert_equal I18n.t("back_office.seasons.publish.published", number: draft.number, locale: :en), flash[:notice]
      assert_predicate draft.reload, :published?
    end

    test "a stale page is refused with stale_draft" do
      sign_in(accounts_players(:administrator))
      draft = seed_card_seasons(distinct_scores(21))

      post publish_back_office_seasons_path(locale: :en), params: { number: "1" }

      assert_equal I18n.t("errors.catalog.stale_draft", locale: :en), flash[:alert]
      assert_predicate draft.reload, :draft?
    end

    test "publishing with no draft is refused with no_draft" do
      sign_in(accounts_players(:administrator))

      get back_office_seasons_path(locale: :en)
      assert_select "form[action$='/seasons/publish']", false

      post publish_back_office_seasons_path(locale: :en), params: { number: "2" }

      assert_equal I18n.t("errors.catalog.no_draft", locale: :en), flash[:alert]
    end

    test "a draft too small is refused with empty_tier" do
      sign_in(accounts_players(:administrator))
      draft = seed_card_seasons(distinct_scores(20))

      post publish_back_office_seasons_path(locale: :en), params: { number: draft.number.to_s }

      assert_equal I18n.t("errors.catalog.empty_tier", locale: :en), flash[:alert]
      assert_predicate draft.reload, :draft?
    end

    test "the back-office links to the seasons for an administrator only" do
      sign_in(accounts_players(:administrator))
      get back_office_path(locale: :fr)

      assert_select "main a.button--secondary[href='/fr/back-office/seasons']", "Les saisons du catalogue"

      sign_in(accounts_players(:moderator))
      get back_office_path(locale: :fr)

      assert_select "a[href$='/seasons']", false
    end

    def each_request(draft)
      yield :get, back_office_seasons_path(locale: :fr), {}
      yield :post, publish_back_office_seasons_path(locale: :fr), { number: draft.number }
    end

    [ :player, :moderator ].each do |role|
      test "a #{role} is refused every season action with 403" do
        draft = seed_card_seasons(distinct_scores(21))
        sign_in(accounts_players(role))

        each_request(draft) do |verb, path, params|
          public_send(verb, path, params:)

          assert_response :forbidden, "#{verb} #{path}"
          assert_includes response.body, ERB::Util.html_escape(I18n.t("authorization.forbidden", locale: :fr))
        end
        assert_predicate draft.reload, :draft?
      end
    end

    test "a visitor is sent to the attic and asked to sign in for every season action" do
      draft = seed_card_seasons(distinct_scores(21))

      each_request(draft) do |verb, path, params|
        public_send(verb, path, params:)

        assert_redirected_to home_path(locale: :fr), "#{verb} #{path}"
        assert_equal I18n.t("authorization.sign_in_required", locale: :fr), flash[:alert]
      end
      assert_predicate draft.reload, :draft?
    end
  end
end

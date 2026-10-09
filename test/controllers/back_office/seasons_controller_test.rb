require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/catalog_seeds"

module BackOffice
  # The catalog seasons page of the back-office (AD-5), administrators only.
  class SeasonsControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
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
      %w[legendary epic rare uncommon common].map { |name| css_select("tr[data-season-number='2'] td[data-season-tier=#{name}]").first&.text }
    end

    test "an administrator sees the seasons and publishes the draft of 150 cards" do
      sign_in(accounts_players(:administrator))
      draft = seed_card_seasons(distinct_scores(150))

      get back_office_seasons_path(locale: :fr)

      assert_response :success
      assert_select "h1", "Les saisons du catalogue"
      assert_select "tr[data-season-number='1'][data-season-status=published] td[data-season-card-count='5']"
      assert_select "tr[data-season-number='1'] td[data-season-tier=epic]", "1"
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

    test "the page shows a published season's sets per kind" do
      sign_in(accounts_players(:administrator))
      draft = seed_sets_draft

      get back_office_seasons_path(locale: :en)
      assert_select "tr[data-season-number='2'] td[data-season-sets-publisher]", false
      assert_select "th", "Publisher sets"

      post publish_back_office_seasons_path(locale: :en), params: { number: draft.number }
      follow_redirect!

      assert_select "tr[data-season-number='2'] td[data-season-sets-publisher='1']", "1"
      assert_select "tr[data-season-number='2'] td[data-season-sets-tome='4']", "4"
      assert_select "tr[data-season-number='2'] td[data-season-sets-best-of-year='3']", "3"
      assert_select "tr[data-season-number='1'] td[data-season-sets-publisher='1']"
    end

    test "the draft's preview follows the seasons, the publish form below it, and publishing gives what it showed" do
      sign_in(accounts_players(:administrator))
      draft = seed_sets_draft

      get back_office_seasons_path(locale: :en)

      assert_response :success
      assert_select "section[data-preview] h2", "Season 2, if published now"
      assert_select "table.ledger ~ section[data-preview] ~ form[action='/en/back-office/seasons/publish']"
      assert_select "section[data-preview] ~ table.ledger", false
      assert_equal %w[2 6 15 37 90], %w[legendary epic rare uncommon common].map { |name| css_select("[data-preview-tier=#{name}]").sole.text }
      assert_equal %w[149.000 143.000 128.000 91.000], %w[legendary epic rare uncommon].map { |name| css_select("[data-preview-threshold=#{name}]").sole.text }
      assert_select "[data-preview-threshold=common]", false
      assert_equal %w[1.000 15.000 75.000 135.000 149.000 150.000], %w[min p10 p50 p90 p99 max].map { |p| css_select("[data-preview-percentile=#{p}]").sole.text }
      assert_select "[data-preview-dust]", false
      assert_select "tr[data-preview-top]", 10
      assert_select "tr[data-preview-top='1'] td", "Seed 0"
      assert_select "tr[data-preview-top='10'] td", "Seed 9"
      assert_select "tr[data-preview-bottom='1'] td", "Seed 149"
      assert_select "th", "Rating"
      assert_equal [ %w[action 75 3], %w[rpg 44 1], %w[none 31 0] ],
        css_select("tr[data-preview-genre]").map { |row| [ row["data-preview-genre"], *row.css("td").map(&:text) ] }
      assert_equal %w[1 4 3], %w[publisher tome best-of-year].map { |kind| css_select("[data-preview-set-kind=#{kind}]").sole.text }

      post publish_back_office_seasons_path(locale: :en), params: { number: draft.number }
      follow_redirect!

      assert_equal %w[2 6 15 37 90], tier_cells
      assert_select "tr[data-season-number='2'] td[data-season-sets-tome='4']", "4"
      assert_select "section[data-preview]", false
    end

    test "the preview shows the empty_tier verdict in place of the tiers of a draft too small" do
      sign_in(accounts_players(:administrator))
      seed_card_seasons(distinct_scores(20))

      get back_office_seasons_path(locale: :fr)

      assert_select "section[data-preview] h2", "La saison 2, si elle était publiée maintenant"
      assert_select "[data-preview-verdict=empty_tier]", I18n.t("errors.catalog.empty_tier", locale: :fr)
      assert_select "[data-preview-tier]", false
      assert_select "[data-preview-percentile=p50]", "10,000"
      assert_select "tr[data-preview-top]", 10
    end

    test "a draft mixing two score versions shows the verdict in the preview, and publishing it is refused with the same message" do
      sign_in(accounts_players(:administrator))
      draft = seed_card_seasons(distinct_scores(150), score_versions: Array.new(149, 2) + [ nil ])
      message = I18n.t("errors.catalog.mixed_score_versions", locale: :fr)

      get back_office_seasons_path(locale: :fr)

      assert_select "[data-preview-verdict=mixed_score_versions]", message
      assert_select "[data-preview-tier=legendary]", "2"
      assert_select "form[action$='/seasons/publish']"

      post publish_back_office_seasons_path(locale: :fr), params: { number: draft.number }

      assert_redirected_to back_office_seasons_path(locale: :fr)
      assert_equal message, flash[:alert]
      assert_predicate draft.reload, :draft?
      assert_equal 0, Catalog::CardSeason.where(season_id: draft.id).where.not(rarity: nil).count
    end

    test "a draft scored by one version shows no score version verdict" do
      sign_in(accounts_players(:administrator))
      seed_card_seasons(distinct_scores(150), score_versions: Array.new(150, 2))

      get back_office_seasons_path(locale: :en)

      assert_select "[data-preview-tier=legendary]", "2"
      assert_select "[data-preview-verdict]", false
    end

    test "the preview of a draft without card shows the empty_season verdict and no number" do
      sign_in(accounts_players(:administrator))
      Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)

      get back_office_seasons_path(locale: :en)

      assert_select "[data-preview-verdict=empty_season]", I18n.t("errors.catalog.empty_season", locale: :en)
      assert_select "[data-preview-percentile], [data-preview-tier], [data-preview-top], [data-preview-genre]", false
    end

    test "with no draft there is no preview" do
      sign_in(accounts_players(:administrator))

      get back_office_seasons_path(locale: :en)

      assert_select "section[data-preview]", false
    end

    test "the preview and the publish form show while an import is unfinished, with the notice" do
      sign_in(accounts_players(:administrator))
      seed_card_seasons(distinct_scores(21))
      Steam::ImportRun.create!(status: :running, step: "cards", started_at: 1.minute.ago)

      get back_office_seasons_path(locale: :en)

      assert_select "[data-preview-tier=legendary]", "1"
      assert_select "main .panel", I18n.t("back_office.seasons.publish.import_active", locale: :en)
      assert_select "form[action$='/seasons/publish']"
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

    test "an abandoned latest run does not block publishing" do
      sign_in(accounts_players(:administrator))
      draft = seed_card_seasons(distinct_scores(21))
      Steam::ImportRun.create!(status: :completed, step: "cards", created_at: 2.days.ago, finished_at: 2.days.ago)
      Steam::ImportRun.create!(status: :abandoned, step: "details", created_at: 1.hour.ago, finished_at: 1.minute.ago)

      get back_office_seasons_path(locale: :en)
      assert_no_match I18n.t("back_office.seasons.publish.import_active", locale: :en), response.body

      post publish_back_office_seasons_path(locale: :en), params: { number: draft.number }

      assert_equal I18n.t("back_office.seasons.publish.published", number: draft.number, locale: :en), flash[:notice]
      assert_predicate draft.reload, :published?
    end

    test "an abandoned latest run does not lift the block of an earlier run that failed after writing cards" do
      sign_in(accounts_players(:administrator))
      draft = seed_card_seasons(distinct_scores(21))
      Steam::ImportRun.create!(status: :completed, step: "cards", created_at: 3.days.ago, finished_at: 3.days.ago)
      Steam::ImportRun.create!(status: :failed, step: "cards", cursor: { "step" => "cards", "last_appid" => 40 }, counts: { "cards_written" => 2 },
        created_at: 2.days.ago, finished_at: 2.days.ago)
      Steam::ImportRun.create!(status: :abandoned, step: "details", created_at: 1.hour.ago, finished_at: 1.minute.ago)

      post publish_back_office_seasons_path(locale: :en), params: { number: draft.number }

      assert_equal I18n.t("back_office.seasons.publish.import_active", locale: :en), flash[:alert]
      assert_predicate draft.reload, :draft?
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

    test "a moderator is refused every season action with 403" do
      draft = seed_card_seasons(distinct_scores(21))
      sign_in(accounts_players(:moderator))

      each_request(draft) do |verb, path, params|
        public_send(verb, path, params:)

        assert_response :forbidden, "#{verb} #{path}"
        assert_includes response.body, ERB::Util.html_escape(I18n.t("authorization.forbidden", locale: :fr))
      end
      assert_predicate draft.reload, :draft?
    end

    test "a visitor and a player get the 404 of an unknown address for every season action" do
      draft = seed_card_seasons(distinct_scores(21))

      [ nil, accounts_players(:player) ].each do |player|
        sign_in(player) if player
        each_request(draft) do |verb, path, params|
          public_send(verb, path, params:)

          assert_unknown_address "#{verb} #{path}"
        end
      end
      assert_predicate draft.reload, :draft?
    end
  end
end

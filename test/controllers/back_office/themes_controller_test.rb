require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/catalog_seeds"
require_relative "../../support/steam_sign_in"

module BackOffice
  # The themes page of the back-office, administrators only: the tags the
  # draft's cards carry, classified or not, and the themes, renamed.
  class ThemesControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include CatalogSeeds
    include SteamSignIn

    def sign_in_origin = "/fr"

    setup do
      @draft = seed_card_seasons(distinct_scores(4))
      tags = [ %w[roguelite pixel_graphics 2d], %w[pixel_graphics indie], %w[pixel_graphics], %w[rpg] ]
      Catalog::Card.joins(:card_seasons).where(catalog_card_seasons: { season_id: @draft.id }).order(:id).zip(tags).each do |card, card_tags|
        card.update_columns(tags: card_tags, genres: Catalog::Themes.of(card_tags))
      end
      Steam::Tag.insert_all([ { tagid: 1, name: "Pixel Graphics" }, { tagid: 2, name: "2D" }, { tagid: 3, name: "Roguelite" } ])
    end

    def rows = [ Catalog::Theme, Catalog::TagClassification ].map { |model| model.order(:id).pluck(Arel.sql("md5(#{model.table_name}::text)")) }

    def tag_row(key) = "tr[data-theme-tag='#{key}']"

    def classification_of(tag_key) = Catalog::TagClassification.find_by(tag_key:)

    test "an administrator sees the unclassified tags of the draft with their game count, most carried first" do
      sign_in(accounts_players(:administrator))
      before = rows

      get back_office_themes_path(locale: :en)

      assert_response :success
      assert_equal before, rows
      assert_select "h1", "The themes"
      assert_equal %w[pixel_graphics 2d], css_select("tr[data-theme-tag]").map { it["data-theme-tag"] }
      assert_select "#{tag_row("pixel_graphics")}[data-theme-tag-state=unclassified]" do
        assert_select "th", /Pixel Graphics/
        assert_select "td", "3"
        assert_select "td", "To classify"
      end
      assert_select "[data-themes-unclassified-count='2']", "2 tags are left to classify."
      assert_select "form[action='/en/back-office/themes/dismiss']", 3
      assert_select "form[action='/en/back-office/themes/dismiss'] input[name='tag_keys[]']", 4
      assert_select "form[action='/en/back-office/themes/dismiss'] button", "Mark the 2 unclassified tags of this page as no theme"
      assert_select "[data-themes-rescore-needed]", false
      assert_select "[style]", false
    end

    test "the page lists every tag, classified ones with their theme or no theme" do
      sign_in(accounts_players(:administrator))

      get back_office_themes_path(locale: :en, show: "all")

      assert_equal %w[pixel_graphics 2d indie roguelite rpg], css_select("tr[data-theme-tag]").map { it["data-theme-tag"] }
      assert_select "#{tag_row("roguelite")}[data-theme-tag-state=theme] td", "Theme: Roguelike"
      assert_select "#{tag_row("indie")}[data-theme-tag-state=dismissed] td", "Not a theme"
      assert_select "#{tag_row("indie")} form[action$='/themes/dismiss']", false
    end

    test "a tag is attached to a theme, then the page says a rescore is needed" do
      sign_in(accounts_players(:administrator))

      get back_office_themes_path(locale: :fr)
      assert_select "#{tag_row("pixel_graphics")} form[action='/fr/back-office/themes/attach']" do
        assert_select "input[name=tag_key][value=pixel_graphics]"
        assert_select "select[name=theme] option", Catalog::Theme.count + 1
      end

      post attach_back_office_themes_path(locale: :fr), params: { tag_key: "pixel_graphics", theme: catalog_themes(:puzzle).token, show: "unclassified", page: "1" }

      assert_redirected_to back_office_themes_path(locale: :fr, show: "unclassified", page: "1")
      assert_equal I18n.t("back_office.themes.attach.attached", locale: :fr), flash[:notice]
      assert_equal catalog_themes(:puzzle), classification_of("pixel_graphics").theme
      follow_redirect!
      assert_select "[data-themes-rescore-needed]"
      assert_select "[data-themes-unclassified-count='1']"
    end

    test "a theme is made of a tag, named in both languages" do
      sign_in(accounts_players(:administrator))

      get back_office_themes_path(locale: :en)
      assert_select "#{tag_row("pixel_graphics")} form[action='/en/back-office/themes'] input[name=name_en][value='Pixel Graphics']"

      post back_office_themes_path(locale: :en), params: { tag_key: "pixel_graphics", name_en: "Pixel art", name_fr: "Pixel art FR" }

      assert_redirected_to back_office_themes_path(locale: :en)
      assert_equal I18n.t("back_office.themes.create.created", locale: :en), flash[:notice]
      theme = Catalog::Theme.find_by!(key: "pixel_graphics")
      assert_equal [ "Pixel art", "Pixel art FR" ], [ theme.name_en, theme.name_fr ]
      assert_equal theme, classification_of("pixel_graphics").theme
    end

    test "a blank name is refused with its reason and creates nothing" do
      sign_in(accounts_players(:administrator))
      before = rows

      post back_office_themes_path(locale: :fr), params: { tag_key: "pixel_graphics", name_en: "Pixel art", name_fr: " " }

      assert_redirected_to back_office_themes_path(locale: :fr)
      assert_equal I18n.t("errors.catalog.invalid_theme_name", locale: :fr), flash[:alert]
      assert_equal before, rows
    end

    test "tags are dismissed one by one or by the page's unclassified rest" do
      sign_in(accounts_players(:administrator))

      post dismiss_back_office_themes_path(locale: :en), params: { tag_keys: %w[2d] }
      assert_equal I18n.t("back_office.themes.dismiss.dismissed", count: 1, locale: :en), flash[:notice]
      post dismiss_back_office_themes_path(locale: :en), params: { tag_keys: %w[pixel_graphics roguelite] }
      assert_equal I18n.t("back_office.themes.dismiss.dismissed", count: 2, locale: :en), flash[:notice]

      assert_equal [ true, true, true ], %w[2d pixel_graphics roguelite].map { classification_of(it).not_a_theme }
      get back_office_themes_path(locale: :en)
      assert_select "[data-themes-unclassified-count='0']", "No tag is left to classify."
      assert_select "tr[data-theme-tag]", false
    end

    test "dismissing nothing is refused" do
      sign_in(accounts_players(:administrator))
      before = rows

      post dismiss_back_office_themes_path(locale: :en)

      assert_equal I18n.t("errors.catalog.invalid_tag", locale: :en), flash[:alert]
      assert_equal before, rows
    end

    test "a theme is renamed and its cards show the new name" do
      sign_in(accounts_players(:administrator))
      theme = catalog_themes(:horror)

      get back_office_themes_path(locale: :en)
      assert_select "tr[data-theme=horror] form[action='/en/back-office/themes/#{theme.token}'] input[name=name_fr][value='Horreur']"
      assert_no_match(/themes\/#{theme.id}\b/, response.body)

      patch back_office_theme_path(theme, locale: :en), params: { name_en: "Scary", name_fr: "Effrayant" }

      assert_redirected_to back_office_themes_path(locale: :en)
      assert_equal I18n.t("back_office.themes.update.updated", locale: :en), flash[:notice]
      assert_equal [ "Scary", "Effrayant" ], catalog_themes(:horror).reload.slice(:name_en, :name_fr).values
      assert_equal "Effrayant", I18n.with_locale(:fr) { SetLabel.genre("horror") }
    end

    test "an unknown theme token is not found" do
      sign_in(accounts_players(:administrator))

      patch back_office_theme_path("A" * 24, locale: :en), params: { name_en: "x", name_fr: "x" }
      assert_response :not_found
      post attach_back_office_themes_path(locale: :en), params: { tag_key: "2d", theme: "A" * 24 }
      assert_response :not_found
    end

    test "attaching with no theme chosen is refused with its reason and writes nothing" do
      sign_in(accounts_players(:administrator))
      before = rows

      get back_office_themes_path(locale: :en)
      assert_select "#{tag_row("pixel_graphics")} select[name=theme][required] option[value='']", "Choose a theme"
      assert_select "#{tag_row("pixel_graphics")} select[name=theme] option:first-child[value='']"

      [ {}, { theme: "" } ].each do |blank|
        post attach_back_office_themes_path(locale: :fr), params: { tag_key: "pixel_graphics", **blank }

        assert_redirected_to back_office_themes_path(locale: :fr)
        assert_equal I18n.t("back_office.themes.attach.theme_required", locale: :fr), flash[:alert]
      end
      assert_equal before, rows
    end

    test "the tags come fifty to a page" do
      sign_in(accounts_players(:administrator))
      more = seed_card_seasons(distinct_scores(60), season: @draft, prefix: "more")
      Catalog::Card.where("source_key LIKE 'test:more-%'").order(:id).each_with_index { |card, index| card.update_columns(tags: [ "tag_#{index}" ]) }
      assert_equal @draft, more

      get back_office_themes_path(locale: :en)
      assert_equal 50, css_select("tr[data-theme-tag]").size
      assert_select "nav[aria-label='Pages of tags'] a[aria-current=page]", "1"

      get back_office_themes_path(locale: :en, page: "2")
      assert_response :success
      assert_equal 12, css_select("tr[data-theme-tag]").size

      get back_office_themes_path(locale: :en, page: "999")
      assert_response :success
      assert_select "nav a[aria-current=page]", "2"
      get back_office_themes_path(locale: :en, page: "nonsense", show: "nonsense")
      assert_response :success
      assert_equal 50, css_select("tr[data-theme-tag]").size
    end

    test "the dashboard links the page to an administrator only" do
      sign_in(accounts_players(:administrator))
      get back_office_path(locale: :en)
      assert_select "a[href='/en/back-office/themes']", "The themes"

      sign_in(accounts_players(:moderator))
      get back_office_path(locale: :en)
      assert_select "a[href='/en/back-office/themes']", false
    end

    def each_request
      theme = catalog_themes(:horror)
      yield :get, back_office_themes_path(locale: :fr), {}
      yield :post, back_office_themes_path(locale: :fr), { tag_key: "2d", name_en: "x", name_fr: "x" }
      yield :patch, back_office_theme_path(theme, locale: :fr), { name_en: "x", name_fr: "x" }
      yield :post, attach_back_office_themes_path(locale: :fr), { tag_key: "2d", theme: theme.token }
      yield :post, dismiss_back_office_themes_path(locale: :fr), { tag_keys: %w[2d] }
    end

    test "a moderator is refused every themes action with 403" do
      sign_in(accounts_players(:moderator))
      before = rows

      each_request do |verb, path, params|
        public_send(verb, path, params:)

        assert_response :forbidden, "#{verb} #{path}"
        assert_includes response.body, ERB::Util.html_escape(I18n.t("authorization.forbidden", locale: :fr))
      end
      assert_equal before, rows
    end

    test "a visitor and a player get the 404 of an unknown address for every themes action" do
      before = rows

      [ nil, accounts_players(:player) ].each do |player|
        sign_in(player) if player
        each_request do |verb, path, params|
          public_send(verb, path, params:)

          assert_unknown_address "#{verb} #{path}"
        end
      end
      assert_equal before, rows
    end
  end
end

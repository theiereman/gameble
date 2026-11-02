require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/roadmap_seeds"
require_relative "../../support/steam_sign_in"

module BackOffice
  # The roadmap editor of the back-office, administrators only: every
  # milestone and story in one form, saved at once, with a preview of the
  # landing's roadmap that writes nothing.
  class RoadmapsControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include RoadmapSeeds
    include SteamSignIn

    def sign_in_origin = "/en"

    setup do
      Rails.cache.clear
      @alpha, @beta = create_roadmap_milestones("alpha", "beta")
      show_roadmap_milestone(@alpha, status: "done")
      @story = add_roadmap_story(@alpha, "one")
    end

    teardown { Rails.cache.clear }

    def row(wording, token: nil, status: "to_come", shown: "1", **extra)
      { "token" => token, "wording_fr" => "FR #{wording}", "wording_en" => wording, "status" => status, "shown" => shown, **extra.transform_keys(&:to_s) }.compact
    end

    def form(milestones, extra = {}) = { milestones:, **extra }

    def tables = [ Catalog::RoadmapMilestone, Catalog::RoadmapStory ].map { |model| model.order(:id).pluck(Arel.sql("md5(#{model.table_name}::text)")) }

    test "an administrator reads every milestone and story as a form of rows identified by token, with the preview rendered" do
      sign_in(accounts_players(:administrator))
      before = tables

      get back_office_roadmap_path(locale: :en)

      assert_response :success
      assert_equal before, tables
      assert_select "form[action='/en/back-office/roadmap'][method=post]" do
        assert_select "input[name='milestones[#{@alpha.token}][token]'][value='#{@alpha.token}']"
        assert_select "input[name='milestones[#{@alpha.token}][wording_en]'][value='Step alpha']"
        assert_select "select[name='milestones[#{@alpha.token}][status]'] option[selected][value=done]"
        assert_select "input[name='milestones[#{@alpha.token}][stories][#{@story.token}][wording_fr]'][value='Récit one']"
        assert_select "input[name='milestones[#{@beta.token}][shown]'][type=checkbox]:not([checked])"
        assert_select "[data-roadmap-list=milestone] > [data-roadmap-row=milestone]", 2
        assert_select "[data-roadmap-list=story] > [data-roadmap-row=story]", 1
        assert_select "template[data-roadmap-editor-target=milestoneTemplate] input[name='milestones[__milestone__][wording_en]']"
        assert_select "template[data-roadmap-editor-target=storyTemplate] input[name='milestones[__milestone__][stories][__story__][wording_en]']"
        assert_select "button[formaction='/en/back-office/roadmap/preview']"
      end
      assert_select "[data-roadmap-preview] .landing-roadmap__milestone", 1
      assert_select "[data-roadmap-preview] .landing-roadmap__name", "Step alpha"
      assert_select "[style]", 0
      assert_select "form [value='#{@alpha.id}'], form [name*='[#{@alpha.id}]'], form [id*='#{@alpha.id}'], form [data-key='#{@alpha.id}']", 0
    end

    test "saving updates, reorders, adds and deletes in one go and redirects with a notice" do
      sign_in(accounts_players(:administrator))

      patch_roadmap = { @beta.token => row("Beta first", token: @beta.token, status: "in_progress"),
                        "new-1" => row("Fresh", shown: "0", stories: { "new-2" => row("Fresh story") }),
                        @alpha.token => row("Alpha last", token: @alpha.token, stories: {}) }
      post back_office_save_roadmap_path(locale: :en), params: form(patch_roadmap)

      assert_redirected_to back_office_roadmap_path(locale: :en)
      assert_equal "The roadmap is saved, officer.", flash[:notice]
      assert_equal [ "Beta first", "Fresh", "Alpha last" ], Catalog::RoadmapMilestone.order(:position).pluck(:wording_en)
      assert_equal [ "Fresh story" ], Catalog::RoadmapStory.pluck(:wording_en)
      assert_equal "in_progress", @beta.reload.status
    end

    test "a refused save answers 422 with the error on the right row and keeps every edit, the other rows included" do
      sign_in(accounts_players(:administrator))
      before = tables

      post back_office_save_roadmap_path(locale: :en), params: form(
        @alpha.token => row("Alpha edited", token: @alpha.token, stories: { @story.token => row("", token: @story.token), "new-1" => row("Typed story") }),
        "new-2" => row("Typed milestone")
      )

      assert_response :unprocessable_content
      assert_equal before, tables
      assert_select "[data-roadmap-failure]", /Some rows of the roadmap need fixing/
      assert_select "[data-roadmap-row][data-key='#{@story.token}'] [data-roadmap-row-failure]", /Each wording needs some text/
      assert_select "[data-roadmap-row-failure]", 1
      assert_select "input[name='milestones[#{@alpha.token}][wording_en]'][value='Alpha edited']"
      assert_select "input[name='milestones[#{@alpha.token}][stories][new-1][wording_en]'][value='Typed story']"
      assert_select "input[name='milestones[new-2][wording_en]'][value='Typed milestone']"
      assert_select "[data-roadmap-preview] .landing-roadmap__name", "Alpha edited"
    end

    test "a row that vanished meanwhile refuses the save with a message" do
      sign_in(accounts_players(:administrator))

      post back_office_save_roadmap_path(locale: :en), params: form("ghost" => row("Ghost", token: "z" * 24))

      assert_response :unprocessable_content
      assert_select "[data-roadmap-failure]", /no longer on the roadmap/
    end

    test "the preview renders what the landing would show from the unsaved rows and writes nothing" do
      sign_in(accounts_players(:administrator))
      before = tables
      events = Rails.configuration.event_store.read.count

      first = row("First", status: "done", stories: { "s1" => row("Seen", status: "in_progress"), "s2" => row("Hidden", shown: "0"), "s3" => row("Second"), "s4" => row("Cut") })

      post preview_back_office_roadmap_path(locale: :en), params: form("a" => first, "b" => row("Hidden milestone", shown: "0"))

      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_select "turbo-stream[action=update][target=roadmap-preview]" do
        assert_select "template .landing-roadmap__milestone", 1
        assert_select "template .landing-roadmap__name", "First"
        assert_select "template .landing-roadmap__story", 2
        assert_select "template .landing-roadmap__story--in-progress", 1
        assert_select "template .landing-roadmap__status", "Done"
      end
      assert_equal before, tables
      assert_equal events, Rails.configuration.event_store.read.count
    end

    test "the preview follows the chosen language and keeps only the landing's first milestones, even with refused rows" do
      sign_in(accounts_players(:administrator))
      milestones = (1..8).to_h { |index| [ "m#{index}", row(index == 1 ? "" : "Stage #{index}") ] }

      post preview_back_office_roadmap_path(locale: :en), params: form(milestones, preview_locale: "fr")

      assert_response :success
      assert_select "template .landing-roadmap__milestone", Catalog::LandingRoadmap::MILESTONE_LIMIT
      assert_select "template .landing-roadmap__name", text: "FR Stage 2"
      assert_select "template .landing-roadmap__status", text: "À venir"
    end

    test "an unknown preview language falls back to the page's" do
      sign_in(accounts_players(:administrator))

      post preview_back_office_roadmap_path(locale: :en), params: form({ "a" => row("Only") }, preview_locale: "xx")

      assert_select "template .landing-roadmap__name", "Only"
    end

    test "a form with nothing in it previews an empty roadmap and saves an empty one" do
      sign_in(accounts_players(:administrator))

      post preview_back_office_roadmap_path(locale: :en), params: { milestones: "junk" }
      assert_response :success
      assert_select "template .landing-roadmap__milestone", 0

      post back_office_save_roadmap_path(locale: :en)
      assert_redirected_to back_office_roadmap_path(locale: :en)
      assert_equal 0, Catalog::RoadmapMilestone.count
    end

    def each_request
      yield :get, back_office_roadmap_path(locale: :fr), {}
      yield :post, back_office_save_roadmap_path(locale: :fr), form("a" => row("Nope"))
      yield :post, preview_back_office_roadmap_path(locale: :fr), form("a" => row("Nope"))
    end

    test "a moderator is refused every roadmap action with 403" do
      sign_in(accounts_players(:moderator))
      before = tables

      each_request do |verb, path, params|
        public_send(verb, path, params:)

        assert_response :forbidden, "#{verb} #{path}"
      end
      assert_equal before, tables
    end

    test "a visitor and a player get the 404 of an unknown address for every roadmap action" do
      before = tables

      [ nil, accounts_players(:player) ].each do |player|
        sign_in(player) if player
        each_request do |verb, path, params|
          public_send(verb, path, params:)

          assert_unknown_address "#{verb} #{path}"
        end
      end
      assert_equal before, tables
    end

    test "the dashboard links the roadmap to an administrator only" do
      sign_in(accounts_players(:administrator))
      get back_office_path(locale: :en)
      assert_select "a[href='/en/back-office/roadmap']"

      sign_in(accounts_players(:moderator))
      get back_office_path(locale: :en)
      assert_select "a[href='/en/back-office/roadmap']", false
    end
  end
end

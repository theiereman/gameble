require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/roadmap_seeds"
require_relative "../../support/steam_sign_in"

module BackOffice
  # The stories under a roadmap milestone, administrators only: added,
  # edited, reordered and deleted from the milestone's page.
  class RoadmapStoriesControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include RoadmapSeeds
    include SteamSignIn

    def sign_in_origin = "/fr"

    setup do
      @milestone, @other = create_roadmap_milestones("epic-one", "epic-two")
    end

    def fields(**changes) = { wording_fr: "Une histoire", wording_en: "A story", status: "to_come", shown: "1" }.merge(changes)

    def listed = css_select("tr[data-roadmap-story] td[data-roadmap-wording=en]").map(&:text)

    def edit_milestone_path = edit_back_office_roadmap_milestone_path(@milestone, locale: :en)

    def roadmap_rows = [ Catalog::RoadmapMilestone, Catalog::RoadmapStory ].map { |model| model.order(:id).pluck(Arel.sql("md5(#{model.table_name}::text)")) }

    def add_story(wording_en, **changes)
      Catalog::CreateRoadmapStory.new.call(milestone: @milestone, wording_fr: wording_en, wording_en:, status: "to_come", shown: true, **changes).value!
    end

    test "an administrator adds two stories, reorders them and deletes one, each reflected on the milestone's page" do
      sign_in(accounts_players(:administrator))

      get edit_milestone_path
      assert_select "main .panel", I18n.t("back_office.roadmap_milestones.edit.no_stories", locale: :en)

      get new_back_office_roadmap_milestone_roadmap_story_path(@milestone, locale: :en)

      assert_response :success
      assert_select "h1", "A new story for “Epic One”"
      assert_select "form[action='/en/back-office/roadmap/#{@milestone.token}/stories'][method=post]" do
        assert_select "input[name=_method]", false
        assert_select "select[name=status] option[selected][value=to_come]"
        assert_select "input#roadmap-shown[checked]"
      end
      assert_select "a[href='/en/back-office/roadmap/#{@milestone.token}/edit']", "Back to the milestone"

      post back_office_roadmap_milestone_roadmap_stories_path(@milestone, locale: :en), params: fields(wording_fr: "Les cartes", wording_en: "Cards")
      assert_redirected_to edit_milestone_path
      assert_response :see_other
      follow_redirect!
      assert_equal I18n.t("back_office.roadmap_stories.create.created", locale: :en), flash[:notice]

      post back_office_roadmap_milestone_roadmap_stories_path(@milestone, locale: :en), params: fields(wording_fr: "Les échanges", wording_en: "Trades", status: "done", shown: "0")
      follow_redirect!

      assert_equal %w[Cards Trades], listed
      cards, trades = Catalog::RoadmapStories.call(@milestone)
      assert_select "tr[data-roadmap-story='#{trades.token}'][data-roadmap-status=done][data-roadmap-shown=false]" do
        assert_select "td[data-roadmap-wording=fr][lang=fr]", "Les échanges"
        assert_select "td", "Done"
        assert_select "td", "Hidden"
        assert_select "a[href='/en/back-office/roadmap/stories/#{trades.token}/edit']", "Edit"
        assert_select "form[action='/en/back-office/roadmap/stories/#{trades.token}'][data-turbo-confirm] input[name=_method][value=delete]"
        assert_select "input[name=direction][value=up]"
        assert_select "input[name=direction][value=down]", false
      end
      assert_select "tr[data-roadmap-story='#{cards.token}'] input[name=direction][value=up]", false

      post move_back_office_roadmap_story_path(trades, locale: :en), params: { direction: "up" }
      assert_redirected_to edit_milestone_path
      follow_redirect!
      assert_equal I18n.t("back_office.roadmap_stories.move.moved", locale: :en), flash[:notice]
      assert_equal %w[Trades Cards], listed

      delete back_office_roadmap_story_path(cards, locale: :en)
      assert_redirected_to edit_milestone_path
      follow_redirect!
      assert_equal I18n.t("back_office.roadmap_stories.destroy.deleted", locale: :en), flash[:notice]
      assert_equal %w[Trades], listed

      get back_office_roadmap_milestones_path(locale: :en)
      assert_select "tr[data-roadmap-milestone='#{@milestone.token}'] td[data-roadmap-story-count='1']"
    end

    test "an administrator edits a story, back on the milestone's page" do
      sign_in(accounts_players(:administrator))
      story = add_story("Cards")

      get edit_back_office_roadmap_story_path(story, locale: :en)

      assert_response :success
      assert_select "h1", "A story of “Epic One”"
      assert_select "form[action='/en/back-office/roadmap/stories/#{story.token}'] input[name=_method][value=patch]"
      assert_select "input[name=wording_en][value=Cards]"

      patch back_office_roadmap_story_path(story, locale: :en), params: fields(wording_en: "Card pages", status: "in_progress", shown: "0")

      assert_redirected_to edit_milestone_path
      follow_redirect!
      assert_equal I18n.t("back_office.roadmap_stories.update.updated", locale: :en), flash[:notice]
      assert_select "tr[data-roadmap-story='#{story.token}'][data-roadmap-status=in_progress][data-roadmap-shown=false] td[data-roadmap-wording=en]", "Card pages"
    end

    test "an invalid new story or edit re-renders its form with 422 and the message" do
      sign_in(accounts_players(:administrator))
      story = add_story("Cards")
      before = roadmap_rows

      post back_office_roadmap_milestone_roadmap_stories_path(@milestone, locale: :fr), params: fields(wording_en: "")

      assert_response :unprocessable_content
      assert_select "[data-roadmap-failure]", I18n.t("errors.catalog.invalid_wording", limit: 200, locale: :fr)
      assert_select "input[name=wording_fr][value='Une histoire']"

      patch back_office_roadmap_story_path(story, locale: :fr), params: fields(status: "later")

      assert_response :unprocessable_content
      assert_select "[data-roadmap-failure]", I18n.t("errors.catalog.invalid_status", locale: :fr)
      assert_equal before, roadmap_rows
    end

    test "moving a story past an edge, or deleting one deleted meanwhile, comes back with the refusal" do
      sign_in(accounts_players(:administrator))
      story = add_story("Cards")

      post move_back_office_roadmap_story_path(story, locale: :en), params: { direction: "down" }

      assert_redirected_to edit_milestone_path
      assert_equal I18n.t("errors.catalog.at_edge", locale: :en), flash[:alert]

      found = Catalog::RoadmapStoryByToken.call(story.token)
      Catalog::DeleteRoadmapStory.new.call(story:)
      @original_call = Catalog::RoadmapStoryByToken.method(:call).unbind
      Catalog::RoadmapStoryByToken.singleton_class.define_method(:call) { |_token| found }
      delete back_office_roadmap_story_path(story, locale: :en)

      assert_redirected_to edit_milestone_path
      assert_equal I18n.t("errors.catalog.story_not_found", locale: :en), flash[:alert]
    ensure
      Catalog::RoadmapStoryByToken.singleton_class.define_method(:call, @original_call) if @original_call
    end

    test "an unknown story or milestone token is a 404 for an administrator" do
      sign_in(accounts_players(:administrator))
      unknown = "A" * 24

      get new_back_office_roadmap_milestone_roadmap_story_path(unknown, locale: :en)
      assert_unknown_address
      post back_office_roadmap_milestone_roadmap_stories_path(unknown, locale: :en), params: fields
      assert_unknown_address
      get edit_back_office_roadmap_story_path(unknown, locale: :en)
      assert_unknown_address
      delete back_office_roadmap_story_path(unknown, locale: :en)
      assert_unknown_address
    end

    def each_request(story)
      yield :get, new_back_office_roadmap_milestone_roadmap_story_path(@milestone, locale: :fr), {}
      yield :post, back_office_roadmap_milestone_roadmap_stories_path(@milestone, locale: :fr), fields
      yield :get, edit_back_office_roadmap_story_path(story, locale: :fr), {}
      yield :patch, back_office_roadmap_story_path(story, locale: :fr), fields
      yield :post, move_back_office_roadmap_story_path(story, locale: :fr), { direction: "up" }
      yield :delete, back_office_roadmap_story_path(story, locale: :fr), {}
    end

    test "a moderator is refused every story action with 403" do
      story = add_story("Cards")
      add_story("Trades")
      sign_in(accounts_players(:moderator))
      before = roadmap_rows

      each_request(story) do |verb, path, params|
        public_send(verb, path, params:)

        assert_response :forbidden, "#{verb} #{path}"
      end
      assert_equal before, roadmap_rows
    end

    test "a visitor and a player get the 404 of an unknown address for every story action" do
      story = add_story("Cards")
      add_story("Trades")
      before = roadmap_rows

      [ nil, accounts_players(:player) ].each do |player|
        sign_in(player) if player
        each_request(story) do |verb, path, params|
          public_send(verb, path, params:)

          assert_unknown_address "#{verb} #{path}"
        end
      end
      assert_equal before, roadmap_rows
    end
  end
end

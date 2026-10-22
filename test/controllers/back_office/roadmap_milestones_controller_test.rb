require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/rake_tasks"
require_relative "../../support/roadmap_seeds"
require_relative "../../support/steam_sign_in"

module BackOffice
  # The roadmap pages of the back-office, administrators only: the
  # milestones the initiative's epics open, reworded, shown, given a status
  # and reordered by staff.
  class RoadmapMilestonesControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include RakeTasks
    include RoadmapSeeds
    include SteamSignIn

    def sign_in_origin = "/fr"

    setup do
      @one, @two, @three = create_roadmap_milestones("epic-one", "epic-two", "epic-three")
    end

    def listed = css_select("tr[data-roadmap-milestone]").map { it["data-roadmap-milestone"] }

    def row(milestone) = "tr[data-roadmap-milestone='#{milestone.token}']"

    def roadmap_rows = [ Catalog::RoadmapMilestone, Catalog::RoadmapStory ].map { |model| model.order(:id).pluck(Arel.sql("md5(#{model.table_name}::text)")) }

    def fields(**changes) = { wording_fr: "Le catalogue", wording_en: "The catalog", status: "in_progress", shown: "1" }.merge(changes)

    test "an administrator sees every milestone in order, hidden and to come, with no move beyond the edges" do
      sign_in(accounts_players(:administrator))
      before = roadmap_rows

      get back_office_roadmap_milestones_path(locale: :en)

      assert_response :success
      assert_equal before, roadmap_rows
      assert_select "h1", "The roadmap"
      assert_equal [ @one, @two, @three ].map(&:token), listed
      assert_select "#{row(@one)}[data-roadmap-status=to_come][data-roadmap-shown=false]" do
        assert_select "td[data-roadmap-wording=fr][lang=fr]", "Epic One"
        assert_select "td[data-roadmap-wording=en][lang=en]", "Epic One"
        assert_select "td code", "epic-one"
        assert_select "td", "To come"
        assert_select "td", "Hidden"
        assert_select "td[data-roadmap-story-count='0']"
        assert_select "a[href='/en/back-office/roadmap/#{@one.token}/edit']", "Edit"
      end
      assert_select "#{row(@one)} form[action='/en/back-office/roadmap/#{@one.token}/move']", 1
      assert_select "#{row(@one)} input[name=direction][value=down]"
      assert_select "#{row(@one)} input[name=direction][value=up]", false
      assert_select "#{row(@two)} input[name=direction]", 2
      assert_select "#{row(@three)} input[name=direction][value=up]"
      assert_select "#{row(@three)} input[name=direction][value=down]", false
      assert_no_match(/data-roadmap-milestone="#{@one.id}"|\/roadmap\/#{@one.id}\b/, response.body)
      assert_select "[style]", false
    end

    test "with no milestone the page says the next deploy creates them" do
      sign_in(accounts_players(:administrator))
      Catalog::RoadmapMilestone.delete_all

      get back_office_roadmap_milestones_path(locale: :fr)

      assert_select "main .panel", I18n.t("back_office.roadmap_milestones.index.empty", locale: :fr)
      assert_select "table.ledger", false
    end

    test "an administrator rewords, shows and moves a milestone, and rerunning the task leaves it as they made it" do
      sign_in(accounts_players(:administrator))

      get edit_back_office_roadmap_milestone_path(@three, locale: :en)

      assert_response :success
      assert_select "h1", "Milestone “Epic Three”"
      assert_select "form[action='/en/back-office/roadmap/#{@three.token}'][method=post]" do
        assert_select "input[name=_method][value=patch]"
        assert_select "input#roadmap-wording-fr[name=wording_fr][value='Epic Three'][maxlength='200']"
        assert_select "input#roadmap-wording-en[name=wording_en][value='Epic Three']"
        assert_select "select#roadmap-status[name=status] option[selected][value=to_come]", "To come"
        assert_select "input#roadmap-shown[type=checkbox][name=shown][value='1']:not([checked])"
        assert_select "input[type=hidden][name=shown][value='0']", 1
        assert_select "label[for=roadmap-wording-fr]", "French wording"
      end
      assert_select "a[href='/en/back-office/roadmap/#{@three.token}/stories/new']", "Add a story"

      patch back_office_roadmap_milestone_path(@three, locale: :en), params: fields(wording_fr: "Les paquets", wording_en: "Packs")

      assert_redirected_to back_office_roadmap_milestones_path(locale: :en)
      assert_response :see_other
      follow_redirect!
      assert_equal I18n.t("back_office.roadmap_milestones.update.updated", locale: :en), flash[:notice]
      assert_select "#{row(@three)}[data-roadmap-status=in_progress][data-roadmap-shown=true]" do
        assert_select "td[data-roadmap-wording=fr]", "Les paquets"
        assert_select "td[data-roadmap-wording=en]", "Packs"
        assert_select "td", "In progress"
        assert_select "td", "Shown"
      end

      post move_back_office_roadmap_milestone_path(@three, locale: :en), params: { direction: "up" }

      assert_redirected_to back_office_roadmap_milestones_path(locale: :en)
      follow_redirect!
      assert_equal I18n.t("back_office.roadmap_milestones.move.moved", locale: :en), flash[:notice]
      assert_equal [ @one, @three, @two ].map(&:token), listed

      capture_io { rake_task("catalog:create_roadmap_milestones").execute }

      assert_equal [ "Les paquets", "Packs", "in_progress", true ], @three.reload.slice(:wording_fr, :wording_en, :status, :shown).values
      assert_equal [ "epic-one", "epic-three", "epic-two" ], Catalog::RoadmapMilestone.ordered.limit(3).pluck(:epic_slug)
    end

    test "unchecking shown hides the milestone again" do
      sign_in(accounts_players(:administrator))
      @two.update!(shown: true)

      patch back_office_roadmap_milestone_path(@two, locale: :en), params: fields(shown: "0")

      assert_not @two.reload.shown
    end

    {
      "a blank wording" => [ { wording_fr: " " }, :invalid_wording ],
      "a wording over the limit" => [ { wording_en: "A" * 201 }, :invalid_wording ],
      "an unknown status" => [ { status: "someday" }, :invalid_status ]
    }.each do |name, (changes, code)|
      test "#{name} re-renders the form with 422 and the message, the values sent kept" do
        sign_in(accounts_players(:administrator))
        before = roadmap_rows

        patch back_office_roadmap_milestone_path(@two, locale: :fr), params: fields(**changes)

        assert_response :unprocessable_content
        assert_equal before, roadmap_rows
        assert_select ".ledger-errors [data-roadmap-failure]", I18n.t("errors.catalog.#{code}", limit: 200, locale: :fr)
        assert_select "input[name=wording_fr][value=?]", fields(**changes)[:wording_fr]
        assert_select "input#roadmap-shown[checked]"
        assert_select "h1", "Étape « Epic Two »"
      end
    end

    test "moving the first up or the last down is refused with at_edge, and an unknown direction too" do
      sign_in(accounts_players(:administrator))

      post move_back_office_roadmap_milestone_path(@one, locale: :en), params: { direction: "up" }
      assert_redirected_to back_office_roadmap_milestones_path(locale: :en)
      assert_equal I18n.t("errors.catalog.at_edge", locale: :en), flash[:alert]

      post move_back_office_roadmap_milestone_path(@three, locale: :en), params: { direction: "down" }
      assert_equal I18n.t("errors.catalog.at_edge", locale: :en), flash[:alert]

      post move_back_office_roadmap_milestone_path(@two, locale: :en), params: { direction: "away" }
      assert_equal I18n.t("errors.catalog.invalid_direction", locale: :en), flash[:alert]

      assert_equal %w[epic-one epic-two epic-three], Catalog::RoadmapMilestone.ordered.pluck(:epic_slug)
    end

    test "an unknown milestone token is a 404 for an administrator" do
      sign_in(accounts_players(:administrator))
      unknown = "A" * 24

      get edit_back_office_roadmap_milestone_path(unknown, locale: :en)
      assert_unknown_address

      patch back_office_roadmap_milestone_path(unknown, locale: :en), params: fields
      assert_unknown_address

      get "/en/back-office/roadmap/#{@one.id}/edit"
      assert_unknown_address
    end

    test "the back-office links to the roadmap for an administrator only" do
      sign_in(accounts_players(:administrator))
      get back_office_path(locale: :fr)

      assert_select "main a.button--secondary[href='/fr/back-office/roadmap']", "La feuille de route"

      sign_in(accounts_players(:moderator))
      get back_office_path(locale: :fr)

      assert_select "a[href$='/roadmap']", false
    end

    def each_request
      yield :get, back_office_roadmap_milestones_path(locale: :fr), {}
      yield :get, edit_back_office_roadmap_milestone_path(@two, locale: :fr), {}
      yield :patch, back_office_roadmap_milestone_path(@two, locale: :fr), fields
      yield :post, move_back_office_roadmap_milestone_path(@two, locale: :fr), { direction: "up" }
    end

    test "a moderator is refused every roadmap milestone action with 403" do
      sign_in(accounts_players(:moderator))
      before = roadmap_rows

      each_request do |verb, path, params|
        public_send(verb, path, params:)

        assert_response :forbidden, "#{verb} #{path}"
        assert_includes response.body, ERB::Util.html_escape(I18n.t("authorization.forbidden", locale: :fr))
      end
      assert_equal before, roadmap_rows
    end

    test "a visitor and a player get the 404 of an unknown address for every roadmap milestone action" do
      before = roadmap_rows

      [ nil, accounts_players(:player) ].each do |player|
        sign_in(player) if player
        each_request do |verb, path, params|
          public_send(verb, path, params:)

          assert_unknown_address "#{verb} #{path}"
        end
      end
      assert_equal before, roadmap_rows
    end
  end
end

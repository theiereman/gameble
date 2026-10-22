require "application_system_test_case"
require_relative "../support/steam_sign_in"

# An administrator attaches a tag to a theme on the themes page, rescores the
# latest import and promotes it: the tag's games leave the UFOs in the
# preview.
class ThemesPageTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include SteamSignIn

  setup do
    Steam::Tag.insert_all([ { tagid: 122, name: "RPG" }, { tagid: 3, name: "Pixel Graphics" } ])
    run = Steam::ImportRun.create!(status: :running, step: "cards", cursor: { "step" => "cards", "last_appid" => 0 },
      counts: { "apps_listed" => 42, "season_number" => Catalog::DraftSeasonNumber.call }, started_at: 1.hour.ago)
    Steam::App.insert_all((1..42).map do |appid|
      { appid:, name: "Game #{appid}", import_run_id: run.id, reviewed_run_id: run.id, details_run_id: run.id,
        review_count: 1_000 * appid, review_percent_positive: 90, name_en: "Game #{appid}", name_fr: "Jeu #{appid}",
        short_description_en: "The game #{appid}.", short_description_fr: "Le jeu #{appid}.", publishers: [ "Studio" ],
        release_on: Date.new(2011, 4, 19), tag_ids: appid > 39 ? [ 3 ] : [ 122 ], store_url_path: "app/#{appid}/",
        image_url: "https://example.test/#{appid}.jpg" }
    end)
    perform_enqueued_jobs { Steam::ImportStepJob.perform_later(run.id, run.reload.cursor) }
    Steam::PromoteImport.new.call(import_run_id: run.id).value!
    @run = run
    mock_steam_sign_in(accounts_players(:administrator).steam_id)
  end

  test "attaching a tag to a theme and rescoring moves its games out of the UFOs in the preview" do
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    visit back_office_seasons_path(locale: :en)
    assert_selector "[data-preview-ufo-count='3'][data-preview-ufo-over-limit]"
    assert_selector "[data-preview-verdict=unclassified_tags]"

    visit back_office_themes_path(locale: :en)
    assert_selector "[data-theme-tag=pixel_graphics][data-theme-tag-state=unclassified]"
    within "[data-theme-tag=pixel_graphics]" do
      find("select[name=theme]").select "Puzzle"
      click_on "Attach"
    end
    assert_no_selector "[data-theme-tag=pixel_graphics]"
    assert_selector "[data-themes-unclassified-count='0']"
    assert_selector "[data-themes-rescore-needed]"

    assert_link "Open the Steam imports", href: back_office_import_runs_path(locale: :en)
    visit back_office_import_run_path(@run, locale: :en)
    assert_selector "[data-import-run-status=promoted]"
    accept_confirm { click_on "Rescore the cards" }
    assert_selector "[data-import-run-status=running]"
    3.times { perform_enqueued_jobs(only: Steam::ImportStepJob) }
    assert_selector "[data-import-run-status=ready]", wait: 8
    accept_confirm { click_on "PROMOTE" }

    visit back_office_seasons_path(locale: :en)
    assert_selector "[data-preview-ufo-count='0']:not([data-preview-ufo-over-limit])"
    assert_selector "tr[data-preview-theme=puzzle] td", text: "3"
    assert_no_selector "[data-preview-verdict=ufo_share_over_limit]"
    assert_no_selector "[data-preview-verdict=rescore_needed]"
  end
end

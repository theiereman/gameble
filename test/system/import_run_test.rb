require "application_system_test_case"

# The import run page follows its run without a manual reload (AD-19).
class ImportRunTest < ApplicationSystemTestCase
  setup do
    OmniAuth.config.test_mode = true
    administrator = accounts_players(:administrator)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{administrator.steam_id}")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  test "an administrator starts an import and watches the app count grow, until the run completes" do
    visit home_path(locale: :en)
    click_on "Enlist through Steam"
    assert_button "Stand down"

    visit back_office_path(locale: :en)
    click_on "The Steam import"
    click_on "Start an import"
    assert_selector "[data-import-run-step=app_list]"
    run = Steam::ImportRun.sole
    assert_selector "[data-import-run-apps-listed]", text: "0"

    run.update!(cursor: { "last_appid" => 20 }, counts: { "apps_listed" => 10_000 })
    assert_selector "[data-import-run-apps-listed]", text: "10,000", wait: 8

    run.update!(status: :completed, finished_at: Time.current, counts: { "apps_listed" => 12_000 })
    assert_selector "[data-import-run-status=completed]", wait: 8
    assert_no_selector "[data-controller=poller]"
    assert_selector "[data-import-run-apps-listed]", text: "12,000"
  end
end

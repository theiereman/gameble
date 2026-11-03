require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# Opening every capsule from the capsule screen with one thumb: the sign-in
# lands there, one button chains the capsules and skips their animation, the
# daily capsule is collected there and opened next, and the phone's tray holds
# the whole hand at its end.
class CapsuleFlowTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze
  OPEN = "button.booster__open".freeze

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
  end

  teardown do
    reduce_motion(false)
  end

  def reduce_motion(on)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: on ? "reduce" : "" } ])
  end

  def sign_in_to_capsules
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    assert_current_path booster_path(locale: :en)
    assert_selector ".booster[data-layout]"
  end

  def opened_packs
    Game::Pack.where(player_id: @player.id).where.not(opened_at: nil)
  end

  def open_and_reveal(count)
    find("#{OPEN}[data-open=open], #{OPEN}[data-open=next]:not([disabled]):not([aria-disabled])").click
    assert_selector ".booster-card[data-dealt]", count:, wait: 10
    click_button "Reveal all"
    assert_selector ".booster-card[data-revealed]", count:, wait: 10
  end

  test "one button opens three capsules in a row, then says the reserve is empty" do
    reduce_motion(true)
    3.times { create_pack(@player) }
    sign_in_to_capsules

    assert_selector "#{OPEN}[data-open=open]"
    open_and_reveal(5)
    eventually("the first capsule should be opened") { opened_packs.count == 1 }

    2.times do |done|
      assert_selector "#{OPEN}[data-open=next]:not([disabled]):not([aria-disabled])", wait: 10
      open_and_reveal(5)
      eventually("capsule #{done + 2} should be opened") { opened_packs.count == done + 2 }
    end

    assert_selector "#{OPEN}[data-open=empty][disabled]", text: "RESERVE EMPTY", wait: 10
    assert_equal 3, opened_packs.distinct.count(:id)
  end

  test "the daily capsule is collected on the capsule screen, then opened by the same button" do
    reduce_motion(true)
    create_pack(@player, opened_at: 1.minute.ago)
    sign_in_to_capsules
    assert_selector "#{OPEN}[data-open=empty]"

    within("#booster-daily") do
      assert_text "DAILY CAPSULE"
      assert_text "READY"
      click_on "Collect"
    end

    assert_no_selector ".booster-daily", wait: 10
    assert_selector ".toast", text: I18n.t("daily_bonuses.create.collected", locale: :en, time: "%{time}").partition("%{time}").first.strip
    assert_selector ".booster-reserves__tab[data-reserve=special][aria-selected=true]", wait: 10
    assert_selector ".booster[data-reserve=special][data-phase=sealed]"
    find("#{OPEN}[data-open=open]").click

    assert_selector ".booster-card[data-dealt]", count: Game::Pack::BONUS_SIZE, wait: 10
    eventually("the daily capsule should be opened") { opened_packs.where(kind: "bonus").count == 1 }
  end

  test "Skip deals the cards at once once the capsule answers" do
    create_pack(@player)
    sign_in_to_capsules
    page.execute_script(<<~JS)
      const send = window.fetch
      window.answeredAt = null
      window.dealtAt = null
      window.fetch = (...request) =>
        new Promise((resolve) => setTimeout(resolve, 1500))
          .then(() => send(...request))
          .then((response) => { window.answeredAt = performance.now(); return response })
      new MutationObserver(() => {
        if (window.dealtAt === null && document.querySelector(".booster").dataset.phase === "dealt") window.dealtAt = performance.now()
      }).observe(document.querySelector(".booster"), { attributes: true, attributeFilter: ["data-phase"] })
    JS

    find("#{OPEN}[data-open=open]").click
    find("#{OPEN}[data-open=skip]:not([disabled]):not([aria-disabled])", text: "SKIP").click

    assert_selector ".booster-card[data-dealt]", count: 5, wait: 10
    eventually("the hand should be dealt") { page.evaluate_script("window.dealtAt !== null") }
    dealing = page.evaluate_script("window.dealtAt - window.answeredAt")
    assert_operator dealing, :<, 300, "the cards should be dealt at once, not after the deal's animation"
    assert_selector ".booster__state", text: /\AINVENTORY\z/
  end

  test "on a phone, the tray holds every card of the capsule once the last one is stored" do
    reduce_motion(true)
    create_pack(@player, cards: fixture_tier_ids)
    resize_to(*PHONE)
    sign_in_to_capsules
    assert_selector ".booster[data-layout=phone]"

    find("#{OPEN}[data-open=open]").click
    assert_selector ".booster[data-layout=phone] .booster__pile .booster-card[data-dealt]", count: 5, wait: 10
    click_button "Reveal all"

    assert_selector ".booster-tray__slot--filled", count: 5, wait: 30
    assert_selector ".booster-tray__slot", count: 5
  end
end

require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The booster records how each capsule was revealed once its last card is
# face up: card by card, or with "Reveal all" (also after some cards turned
# by hand), for every pack kind, on desktop and phone. A capsule shown again
# face up records nothing. Reduced motion is emulated in every test.
class BoosterRevealModeTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
    reduce_motion(true)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  teardown do
    reduce_motion(false)
  end

  def reduce_motion(on)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: on ? "reduce" : "" } ])
  end

  def card_ids(*names)
    names.map { |name| catalog_card_seasons(name).id }
  end

  def open_screen(cards, kind: :regular)
    @pack = create_pack(@player, cards: card_ids(*cards), kind:, available_at: 1.day.ago)
    visit booster_path(locale: :en)
    assert_selector ".booster"
    record_reveal_posts
  end

  def record_reveal_posts
    page.execute_script(<<~JS)
      window.revealPosts = []
      const realFetch = window.fetch
      window.fetch = (url, init) => {
        if (String(url).endsWith("/reveal")) window.revealPosts.push(init && init.body)
        return realFetch(url, init)
      }
    JS
  end

  def reveal_posts
    page.evaluate_script("window.revealPosts")
  end

  def hit(position)
    ".booster-card:nth-child(#{position}) .booster-card__hit"
  end

  def open_canister
    find(".booster-canister").click
  end

  def assert_dealt(count)
    assert_selector ".booster-card[data-dealt]", count:, wait: 10
    assert_selector ".booster__state", text: /\AINVENTORY\z/
  end

  def assert_reveal_mode(mode)
    eventually("the pack's reveal mode should be #{mode}, not #{@pack.reload.reveal_mode.inspect}") { @pack.reload.reveal_mode == mode }
  end

  test "a regular capsule turned card by card records one_by_one once its last card is face up" do
    open_screen(%i[common_card_one uncommon_card_one rare_card_one portal_one common_card_one])
    open_canister
    assert_dealt(5)

    (1..4).each do |position|
      find(hit(position)).click
      assert_selector ".booster-card[data-revealed]", count: position
    end
    assert_nil @pack.reload.reveal_mode
    assert_empty reveal_posts

    find(hit(5)).click
    assert_selector ".booster-card[data-revealed]", count: 5

    assert_reveal_mode "one_by_one"
    assert_equal [ '{"mode":"one_by_one"}' ], reveal_posts
  end

  test "a bonus capsule finished with Reveal all after a card turned by hand records all" do
    open_screen(%i[rare_card_one portal_one common_card_one], kind: :bonus)
    open_canister
    assert_dealt(3)

    find(hit(1)).click
    assert_selector ".booster-card[data-revealed]", count: 1
    click_on "Reveal all"
    assert_selector ".booster-card[data-revealed]", count: 3, wait: 15

    assert_reveal_mode "all"
    assert_equal [ '{"mode":"all"}' ], reveal_posts
  end

  test "on a phone Reveal all records all" do
    resize_to(*PHONE)
    open_screen(%i[common_card_one uncommon_card_one rare_card_one portal_one common_card_one])
    open_canister
    assert_selector ".booster[data-layout=phone] .booster__pile .booster-card[data-dealt]", count: 5, wait: 10

    click_on "Reveal all"
    assert_selector ".booster-tray__slot--filled", count: 5, wait: 20

    assert_reveal_mode "all"
    assert_equal [ '{"mode":"all"}' ], reveal_posts
  end

  test "a capsule shown again face up records nothing" do
    @pack = create_pack(@player, cards: card_ids(*[ :common_card_one ] * 5), opened_at: 1.minute.ago)
    # A Turbo visit keeps the window, so the recorder sees the screen's first requests.
    record_reveal_posts
    page.execute_script("Turbo.visit(#{booster_path(locale: :en, pack: @pack.token).to_json})")

    assert_current_path booster_path(locale: :en, pack: @pack.token)
    assert_selector ".booster-card[data-revealed]", count: 5
    assert_selector ".booster__state", text: "INVENTORY COMPLETE"

    assert_empty reveal_posts
    assert_nil @pack.reload.reveal_mode
  end
end

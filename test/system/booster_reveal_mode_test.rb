require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The booster records how a capsule was revealed once its last card is face
# up. Reduced motion is emulated in every test.
class BoosterRevealModeTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

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
    assert_equal 1, reveal_posts.size
    posted = JSON.parse(reveal_posts.first)
    assert_equal({ "mode" => "one_by_one", "layout" => "wide" }, posted.slice("mode", "layout"))
    assert_kind_of Integer, posted["touch_to_blast"]
    assert_kind_of Integer, posted["touch_to_first_face"]
  end
end

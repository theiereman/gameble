require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# Returning to the hub with the Gameble button from a submenu and from the
# booster: no block of the hub moves between its first paint and the moment
# the page has settled.
class HubReturnStabilityTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  SCOPE = ".top-bar, .top-bar *, .hub, .hub *, .ticker".freeze
  SAMPLER = <<~JS.freeze
    window.__hubSamples = []
    const started = performance.now()
    const describe = (node) => node.tagName.toLowerCase() + "." + [...node.classList].join(".")
    const sample = () => {
      const frame = {}
      frame.scrollY = [0, Math.round(window.scrollY), 0, 0]
      document.querySelectorAll(#{SCOPE.to_json}).forEach((node, index) => {
        if (node.closest(".hub-showcase__stage") || (node.closest("svg") && node.tagName !== "svg")) return
        const box = node.getBoundingClientRect()
        frame[index + " " + describe(node)] = [Math.round(box.left * 10) / 10, Math.round(box.top * 10) / 10, Math.round(box.width * 10) / 10, Math.round(box.height * 10) / 10]
      })
      window.__hubSamples.push({ at: Math.round(performance.now() - started), path: location.pathname, preview: document.documentElement.hasAttribute("data-turbo-preview"), frame })
      if (performance.now() - started < 2500) requestAnimationFrame(sample)
    }
    requestAnimationFrame(sample)
  JS

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
    gained = 1.hour.ago.change(usec: 0)
    Game::Holding.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 1, last_gained_at: gained)
    2.times { create_pack(@player) }
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    assert_selector ".hub-showcase"
  end

  def hub_frames
    page.evaluate_script("window.__hubSamples").select { |sample| sample["path"] == home_path(locale: :en) && sample["frame"].keys.any? { it.end_with?(" nav.hub-menu") } }
  end

  def assert_hub_does_not_move
    sleep 2.7
    frames = hub_frames
    assert_not_empty frames
    settled = frames.last["frame"]
    moved = frames.flat_map do |sample|
      sample["frame"].filter_map { |selector, box| "#{selector} at #{sample['at']}ms (preview=#{sample['preview']}): #{box} -> #{settled[selector]}" if box != settled[selector] }
    end
    assert_empty moved.first(12), "hub blocks moved after their first paint"
  end

  def return_to_hub_from(path)
    visit path
    assert_selector ".top-bar__start a.top-bar__home, .top-bar__start a.top-bar__phone-home, .top-bar__start a.top-bar__bridge"
    page.execute_script("window.scrollTo(0, 300)")
    page.execute_script(SAMPLER)
    find(".top-bar__start a.top-bar__home, .top-bar__start a.top-bar__phone-home, .top-bar__start a.top-bar__bridge", match: :first).click
    assert_current_path home_path(locale: :en)
    assert_hub_does_not_move
  end

  test "the hub does not move when the Gameble button leads back from the collection" do
    return_to_hub_from library_path(locale: :en)
  end

  test "the hub does not move when the Gameble button leads back from the feed" do
    return_to_hub_from feed_path(locale: :en)
  end

  test "the hub does not move when the Gameble button leads back from the booster" do
    return_to_hub_from booster_path(locale: :en)
  end

  test "the hub does not move in a window shorter than the hub" do
    resize_to(1280, 640)
    return_to_hub_from library_path(locale: :en)
  end

  test "the hub does not move on a phone" do
    resize_to(390, 844)
    return_to_hub_from library_path(locale: :en)
  end
end

require "application_system_test_case"
require_relative "../support/custom_sets"
require_relative "../support/game_packs"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

# The daily capsule collected on the capsule screen, then opened by the same
# button; an empty reserve proposes the sets, the friends and the profile.
class CapsuleFlowTest < ApplicationSystemTestCase
  include CustomSets
  include GamePacks
  include GameSets
  include Holdings
  include SteamSignIn
  OPEN = "button.booster__open".freeze
  NEXT_STEPS = ".booster-next-steps".freeze
  PHONE = [ 390, 844 ].freeze

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

  # A set two cards from bronze, a goal whose card a friend spares, and a reward to claim.
  def give_hooks
    members = unheld_cards(6)
    insert_set(members, { bronze: 4, complete: 6 }, key: "roguelike")
    hold_all(@player, members.first(2))
    friend = accounts_players(:moderator)
    friend.update!(persona_name: "Léa")
    low, high = [ @player.id, friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    wanted = catalog_card_seasons(:portal_one)
    card_ids = Catalog::CardSeason.where(id: [ wanted.id, *unheld_cards(2) ]).pluck(:card_id)
    Game::AddGoal.new.call(player: @player, custom_set: create_custom_set(@player, name: "Favourites", card_ids:).token).value!
    hold(friend, wanted.id, 2)
    Game::AchievementUnlock.record(@player.id, "boosters_100", Time.current, claimed: false)
  end

  def assert_next_steps(hooks)
    within(NEXT_STEPS) do
      assert_selector "h2", text: /what next\?/i
      assert_selector ".booster-next-steps__link", count: 3, wait: 10
      links = all(".booster-next-steps__link")
      assert_equal [ library_path(locale: :en), social_path(locale: :en), me_path(locale: :en) ], links.map { URI(it[:href]).path }
      links.zip(hooks).each { |link, hook| assert_match hook, link.text }
    end
  end

  def follow_next_step(name, path)
    visit booster_path(locale: :en)
    within(NEXT_STEPS) { find(".booster-next-steps__link", text: name).click }
    assert_current_path path
  end

  def opened_packs
    Game::Pack.where(player_id: @player.id).where.not(opened_at: nil)
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

  test "an empty reserve proposes the sets, the friends and the profile, on a phone and on a desktop" do
    reduce_motion(true)
    give_hooks
    create_pack(@player, opened_at: 1.minute.ago)
    resize_to(*PHONE)
    sign_in_to_capsules
    assert_selector ".booster[data-layout=phone][data-phase=empty]"

    hooks = [ /2 more for bronze/i, /Léa has a card one of your goals needs/, /1 reward to claim/ ]
    assert_next_steps(hooks)

    resize_to(1280, 900)
    assert_selector ".booster[data-layout=wide]", wait: 10
    assert_next_steps(hooks)

    follow_next_step(/your sets/i, library_path(locale: :en))
    follow_next_step(/your friends/i, social_path(locale: :en))
    follow_next_step(/your profile/i, me_path(locale: :en))
  end

  test "revealing the last capsule shows the proposals, loaded without a page reload" do
    reduce_motion(true)
    create_pack(@player)
    sign_in_to_capsules
    assert_no_selector NEXT_STEPS
    page.execute_script("window.sameScreen = true")

    find("#{OPEN}[data-open=open]").click
    assert_selector ".booster-card[data-dealt]", count: Game::Pack::SIZE, wait: 10
    assert_no_selector NEXT_STEPS

    click_on "Reveal all"
    assert_selector ".booster-card[data-revealed]", count: Game::Pack::SIZE, wait: 15
    assert_selector "#{NEXT_STEPS} turbo-frame[src$='/en/booster/next-steps'] .booster-next-steps__link", count: 3, wait: 10
    assert_no_selector "#{NEXT_STEPS} .booster-next-steps__hook"
    assert page.evaluate_script("window.sameScreen")
  end
end

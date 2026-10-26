require "application_system_test_case"
require_relative "../support/game_packs"

class LandingLiveFeedTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include GamePacks

  setup do
    @hugo = accounts_players(:player)
    @hugo.update!(persona_name: "Hugo")
  end

  def open_pack(cards: [ catalog_card_seasons(:portal_one).id ] * 5)
    create_pack(@hugo, cards:)
    Game::OpenPack.new.call(player: @hugo).value!
    perform_enqueued_jobs(only: LiveFeedJob)
  end

  def scroll_to_module
    page.execute_script("document.getElementById('landing-live').scrollIntoView()")
  end

  def listening
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    page.execute_script("window.liveMark = true")
  end

  def not_reloaded? = page.evaluate_script("window.liveMark === true")

  def first_entry_sentence = find("#feed-entries > li:first-child .feed__sentence").text

  test "a landing never scrolled to the live module opens no subscription" do
    visit home_path(locale: :en)

    assert_selector "#landing-live", visible: :all
    assert_no_selector "turbo-cable-stream-source", visible: :all
  end

  test "an opening tops the list as one node per entry and the list keeps four" do
    visit home_path(locale: :en)
    scroll_to_module
    listening
    assert_no_selector "#feed-entries > li"

    open_pack

    assert_selector "#feed-entries > li", count: LiveStream::LANDING_SIZE
    assert_equal "Hugo completes the Valve set.", first_entry_sentence
    assert_selector "#feed-entries > li:first-child .feed__sentence a.feed__name", text: "Hugo"
    assert_no_selector ".landing-live__empty"
    assert_no_selector ".landing-live [aria-live], .landing-live [role=status]"
    assert not_reloaded?

    create_pack(@hugo, cards: [ catalog_card_seasons(:legendary_card_one).id ] * 5)
    Game::OpenPack.new.call(player: @hugo).value!
    perform_enqueued_jobs(only: LiveFeedJob)

    assert_selector "#feed-entries > li:first-child .feed__tag--legendary"
    assert_selector "#feed-entries > li", count: LiveStream::LANDING_SIZE
    assert not_reloaded?
  end

  test "entries wait while the pointer is over the list and arrive together afterwards" do
    visit home_path(locale: :en)
    scroll_to_module
    listening

    find(".landing-live__feed").hover
    open_pack
    sleep 0.5
    assert_no_selector "#feed-entries > li"

    find("header").hover
    assert_selector "#feed-entries > li", count: LiveStream::LANDING_SIZE
  end

  test "entries wait while focus is inside the module" do
    visit home_path(locale: :en)
    scroll_to_module
    listening

    page.execute_script("document.querySelector('.landing-live__open').focus()")
    open_pack
    sleep 0.5
    assert_no_selector "#feed-entries > li"

    page.execute_script("document.activeElement.blur()")
    assert_selector "#feed-entries > li", count: LiveStream::LANDING_SIZE
  end
end

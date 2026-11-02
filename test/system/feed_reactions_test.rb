require "application_system_test_case"
require_relative "../support/feed_reactions"
require_relative "../support/steam_sign_in"

# Reacting from the feed: the reaction, its change and its removal update
# the bar in place, keep the scroll and the focus, and every other open
# feed sees the counter move without a reload.
class FeedReactionsTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include FeedReactions
  include SteamSignIn

  setup do
    @author = accounts_players(:player)
    @author.update!(persona_name: "Hugo")
    @reader = accounts_players(:moderator)
    @entry = feed_entry_of(@author, at: 1.hour.ago)
    12.times { |index| feed_entry_of(@author, at: index.minutes.ago) }
    @bar = "#reactions-#{@entry.token}"
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def count_of(kind) = "##{ReactionStream.count_id(@entry.token, kind)}"

  def press(kind) = find("#{@bar} [data-reaction-kind=#{kind}]").click

  def scroll_y = page.evaluate_script("window.scrollY")

  def not_reloaded? = page.evaluate_script("window.liveMark === true")

  def broadcast_counts = perform_enqueued_jobs(only: ReactionCountsJob)

  def assert_counts(thumb:, heart:)
    assert_selector count_of("thumb"), text: thumb.to_s
    assert_selector count_of("heart"), text: heart.to_s
  end

  test "a player reacts, changes and removes a reaction in place, keeping the scroll and the focus, and another browser sees the counters move" do
    sign_in(@reader)
    visit feed_path(locale: :en)
    page.execute_script("window.liveMark = true")
    page.execute_script("document.querySelector('#{@bar}').scrollIntoView({ block: 'center' })")
    assert_selector @bar
    scrolled = scroll_y
    assert_operator scrolled, :>, 0

    using_session("other browser") do
      visit feed_path(locale: :en)
      assert_selector "turbo-cable-stream-source[connected]", visible: :all
      assert_selector "#{@bar} .feed__reaction--static", count: 5
      assert_no_selector "#{@bar} button"
      page.execute_script("window.liveMark = true")
    end

    press("thumb")
    assert_selector "#{@bar} [data-reaction-kind=thumb][aria-pressed=true]"
    assert_counts(thumb: 1, heart: 0)
    eventually("the pressed reaction should keep the focus") { page.evaluate_script("document.activeElement.dataset.reactionKind") == "thumb" }
    assert_selector "#reaction-status", text: "Reaction sent: Thumb up.", visible: :all
    broadcast_counts
    using_session("other browser") do
      assert_counts(thumb: 1, heart: 0)
      assert not_reloaded?
    end

    press("heart")
    assert_selector "#{@bar} [data-reaction-kind=heart][aria-pressed=true]"
    assert_selector "#{@bar} button[aria-pressed=true]", count: 1
    assert_counts(thumb: 0, heart: 1)
    broadcast_counts
    using_session("other browser") { assert_counts(thumb: 0, heart: 1) }

    press("heart")
    assert_no_selector "#{@bar} button[aria-pressed=true]"
    assert_counts(thumb: 0, heart: 0)
    assert_selector "#reaction-status", text: "Reaction removed.", visible: :all
    eventually("the reaction removed should keep the focus") { page.evaluate_script("document.activeElement.dataset.reactionKind") == "heart" }
    broadcast_counts
    using_session("other browser") do
      assert_counts(thumb: 0, heart: 0)
      assert not_reloaded?
    end

    assert_equal scrolled, scroll_y
    assert not_reloaded?
    assert_empty Game::FeedReaction.all
  end

  test "an entry that tops the live feed loads the viewer's own bar with their reaction marked, and a visitor still cannot react" do
    sign_in(@reader)
    visit feed_path(locale: :en)
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    at = Time.current.change(usec: 0)
    fresh = feed_entry_of(@author, at:)
    react(@reader, fresh, "gg")

    LiveFeedJob.perform_now([ { player_id: @author.id, card_season_id: fresh.card_season_id, at: } ])

    frame = "#reactions-#{fresh.token}"
    assert_selector "#{frame} button", count: 5
    assert_selector "#{frame} button[data-reaction-kind=gg][aria-pressed=true]"
    assert_selector "#{frame} button[aria-pressed=true]", count: 1

    using_session("visitor") do
      visit feed_path(locale: :en)
      assert_selector "#{frame} .feed__reaction--static", count: 5
      assert_no_selector ".feed__reactions button"
    end
  end
end

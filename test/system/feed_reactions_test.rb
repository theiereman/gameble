require "application_system_test_case"
require_relative "../support/feed_reactions"
require_relative "../support/steam_sign_in"

# Reacting from the feed through the +: the reaction, its change and its
# removal update the bar in place, keep the scroll and the focus, and every
# other open feed sees the counter move without a reload.
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

  def count_of(kind) = "[data-reaction-count='#{ReactionStream.slot(@entry.token, kind)}']"

  def counts_of(kind) = page.evaluate_script("[...document.querySelectorAll(\"#{count_of(kind)}\")].map(count => count.textContent)").uniq

  def choose(kind) = find("#{@bar} .feed__reaction-choice[data-reaction-kind=#{kind}]").click

  def own_reaction = "#{@bar} .feed__reaction--mine"

  def focused?(selector) = page.evaluate_script("document.activeElement.matches(\"#{selector}\")")

  def scroll_y = page.evaluate_script("window.scrollY")

  def not_reloaded? = page.evaluate_script("window.liveMark === true")

  def broadcast_counts = perform_enqueued_jobs(only: ReactionCountsJob)

  def assert_counts(thumb:, heart:)
    shown = ->(count) { [ count.positive? ? count.to_s : "" ] }
    eventually("thumb should count #{thumb} and heart #{heart}") { counts_of("thumb") == shown.(thumb) && counts_of("heart") == shown.(heart) }
  end

  test "a player reacts from the +, changes and removes the reaction in place, keeping the scroll and the focus, and another browser sees the counters move" do
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
      assert_selector "#{@bar} .feed__reaction--static", count: 5, visible: :all
      assert_no_selector "#{@bar} .feed__reaction"
      assert_no_selector "#{@bar} button", visible: :all
      page.execute_script("window.liveMark = true")
    end

    assert_no_selector "#{@bar} .feed__reaction-choice"
    find("#{@bar} [data-reaction-toggle]").click
    assert_selector "#{@bar} [data-reaction-toggle][aria-expanded=true]"
    choose("thumb")
    assert_selector "#{own_reaction}[data-reaction-kind=thumb][aria-pressed=true]"
    assert_no_selector "#{@bar} [data-reaction-toggle]", visible: :all
    assert_counts(thumb: 1, heart: 0)
    eventually("the own reaction should take the focus") { focused?(own_reaction) }
    assert_selector "#reaction-status", text: "Reaction sent: Thumb up.", visible: :all
    broadcast_counts
    using_session("other browser") do
      assert_counts(thumb: 1, heart: 0)
      assert_selector "#{@bar} .feed__reaction--static", count: 1
      find("#{@bar} [data-reaction-pill=thumb]").hover
      assert_selector "#{@bar} [data-reaction-pill=thumb] .feed__reaction-who-head", text: "Thumb up · 1"
      assert not_reloaded?
    end

    find(own_reaction).hover
    choose("heart")
    assert_selector "#{own_reaction}[data-reaction-kind=heart][aria-pressed=true]"
    assert_selector "#{@bar} .feed__reaction-choice[aria-pressed=true]", count: 1, visible: :all
    assert_counts(thumb: 0, heart: 1)
    broadcast_counts
    using_session("other browser") { assert_counts(thumb: 0, heart: 1) }

    find(own_reaction).click
    assert_selector "#{@bar} [data-reaction-toggle][aria-expanded=false]"
    assert_no_selector "#{@bar} [aria-pressed=true]", visible: :all
    assert_counts(thumb: 0, heart: 0)
    assert_selector "#reaction-status", text: "Reaction removed.", visible: :all
    eventually("the + should take the focus back") { focused?("#{@bar} [data-reaction-toggle]") }
    broadcast_counts
    using_session("other browser") do
      assert_counts(thumb: 0, heart: 0)
      assert_no_selector "#{@bar} .feed__reaction"
      assert not_reloaded?
    end

    assert_equal scrolled, scroll_y
    assert not_reloaded?
    assert_empty Game::FeedReaction.all
  end

  test "an entry that tops the live feed loads the viewer's own bar with their reaction in place of the +, and a visitor still cannot react" do
    sign_in(@reader)
    visit feed_path(locale: :en)
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    at = Time.current.change(usec: 0)
    fresh = feed_entry_of(@author, at:)
    react(@reader, fresh, "gg")

    LiveFeedJob.perform_now([ { player_id: @author.id, card_season_id: fresh.card_season_id, at: } ])

    frame = "#reactions-#{fresh.token}"
    assert_selector "#{frame} .feed__reaction--mine[data-reaction-kind=gg][aria-pressed=true]", text: "1"
    assert_selector "#{frame} .feed__reaction-pill button", count: 5, visible: :all
    assert_selector "#{frame} button", count: 1
    assert_no_selector "#{frame} [data-reaction-toggle]", visible: :all

    using_session("visitor") do
      visit feed_path(locale: :en)
      assert_selector "#{frame} .feed__reaction--static", count: 1, text: "1"
      assert_selector "#{frame} .feed__reaction--static", count: 5, visible: :all
      assert_no_selector ".feed__reactions button", visible: :all
    end
  end
end

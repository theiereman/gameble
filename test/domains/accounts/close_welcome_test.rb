require "test_helper"

class Accounts::CloseWelcomeTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @player = accounts_players(:player)
    @player.update_columns(welcome_pending: true)
  end

  def close(player = @player) = Accounts::CloseWelcome.new.call(player_id: player.id)

  test "a pending welcome closes for good, publishing nothing; closing again changes nothing" do
    events = Rails.configuration.event_store.read.count

    assert_equal true, close.value!
    assert_not @player.reload.welcome_pending
    assert_equal false, close.value!
    assert_equal events, Rails.configuration.event_store.read.count
  end

  test "a player created without a sign-up has none pending" do
    player = Accounts::Player.create!(steam_id: "76561197960287931")

    assert_not player.reload.welcome_pending
    assert_equal false, close(player).value!
  end

  test "a banned player's welcome is left as it is" do
    @player.update_columns(banned_at: Time.current)

    assert_equal false, close.value!
    assert_predicate @player.reload, :welcome_pending
  end

  test "the job closes the welcome" do
    perform_enqueued_jobs { Accounts::CloseWelcomeJob.perform_later(@player.id) }

    assert_not @player.reload.welcome_pending
  end
end

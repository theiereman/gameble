require "test_helper"

class Accounts::SendFeedbackTest < ActiveSupport::TestCase
  setup { @player = accounts_players(:player) }

  def send_feedback(feature: "duels", message: "The clock is too short.", player: @player)
    Accounts::SendFeedback.new.call(player:, feature:, message:)
  end

  test "a feedback is saved with its message trimmed, publishing its sending" do
    feedback = send_feedback(message: "  The clock is too short.\n").value!

    assert_equal "The clock is too short.", feedback.message
    assert_equal [ @player, "duels", 24 ], [ feedback.player, feedback.feature, feedback.token.length ]
    event = Rails.configuration.event_store.read.stream("Accounts::Player$#{@player.id}").last
    assert_kind_of Accounts::FeedbackSent, event
    assert_equal({ feedback_id: feedback.id, player_id: @player.id, feature: "duels" }, event.data)
  end

  test "a browser's line breaks count once, as the form's limit counts them" do
    feedback = send_feedback(message: "one\r\ntwo").value!

    assert_equal "one\ntwo", feedback.message
    assert send_feedback(message: "x\r\n" * 500).success?
  end

  test "a feature that was not opened to feedback is refused" do
    assert_equal :unknown_feature, send_feedback(feature: "market").failure
  end

  test "an empty message or one over the limit is refused" do
    [ " \n", nil, "x" * 1001 ].each { assert_equal :invalid_feedback, send_feedback(message: it).failure }
    assert_empty Accounts::Feedback.all
  end

  test "a banned player cannot send one" do
    @player.update!(banned_at: Time.current)

    assert_equal :player_required, send_feedback.failure
  end
end

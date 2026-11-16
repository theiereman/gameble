require "test_helper"
require_relative "../support/live_duels"

# The push of a duel's change: each seat gets, in each locale, its own board on its own stream, holding its own hand
# only, and the answerer never the locked call's stat or direction.
class DuelStreamJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @lea.update!(persona_name: "Léa")
    @hugo.update!(persona_name: "Hugo")
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    @duel = start_duel(@lea, @hugo)
  end

  def stream(role, locale) = DuelStream.streamables(Game::DuelSeat.find_by!(duel_id: @duel.id, role:).stream_key, locale).join(":")

  def board(role, locale)
    message = ActiveSupport::JSON.decode(broadcasts(stream(role, locale)).sole)
    replace = Nokogiri::HTML5.fragment(message).at_css("turbo-stream[action=replace][target=duel-board]")
    Nokogiri::HTML5.fragment(replace.at_css("template").inner_html)
  end

  def prefix(role) = role == "challenger" ? "Lea" : "Hugo"

  test "the pushes run on the duels queue" do
    assert_equal "duels", DuelStreamJob.new.queue_name
  end

  test "after a call, each seat gets one board per locale with its own hand, and only the caller sees the call" do
    call_round(@duel)
    duel = Game::Duel.find(@duel.id)
    rules = rules_of(duel)
    locked = rules.pending
    words = I18n.t("duel_stats.directions.#{locked.stat}.#{locked.direction}", locale: :en)

    DuelStreamJob.perform_now([ duel.id, duel.id ])

    %w[challenger opponent].each do |role|
      %i[en fr].each { |locale| assert_equal 1, broadcasts(stream(role, locale)).size, "#{role} #{locale}" }
      english = board(role, :en)
      assert_equal "2", english.at_css("#duel-board")["data-move-number"]
      hand = english.at_css("#duel-hand").text
      assert_equal rules.hand(role.to_sym).size, english.css("#duel-hand label, #duel-hand li").size
      assert_includes hand, "#{prefix(role)} card"
      assert_not_includes hand, "#{prefix(other_role(role))} card"
      assert_equal 12, english.css("#duel-my-deck li").size
      assert_equal 12, english.css("#duel-their-deck li").size
    end
    caller = rules.caller.to_s
    answerer = rules.answerer.to_s
    assert_equal words, board(caller, :en).at_css("#duel-current-call h2").text.strip
    assert_not_includes board(answerer, :en).text, words
    assert_equal "Hidden call", board(answerer, :en).at_css("#duel-current-call h2").text.strip
    assert_equal "Annonce cachée", board(answerer, :fr).at_css("#duel-current-call h2").text.strip
    assert board(answerer, :en).at_css("form#duel-answer")
    assert_nil board(caller, :en).at_css("form#duel-call, form#duel-answer")
  end

  test "nothing else is pushed: not the players' own streams, not a seat with no player" do
    Game::DuelSeat.where(duel_id: @duel.id, role: "opponent").update_all(player_id: nil, status: "left")

    DuelStreamJob.perform_now([ @duel.id ])

    assert_equal 1, broadcasts(stream("challenger", :en)).size
    assert_empty broadcasts(stream("opponent", :en))
    assert_empty broadcasts(PlayerStream.name(@lea, :en))
    assert_empty broadcasts(PlayerStream.name(@hugo, :en))
  end

  test "a pushed form names its cards by their place in the deck and the duel by its token, with no session field" do
    Game::Duel.where(id: @duel.id).update_all(first_caller: "challenger")
    rules = rules_of(Game::Duel.find(@duel.id))

    DuelStreamJob.perform_now([ @duel.id ])

    form = board("challenger", :en).at_css("form#duel-call")
    assert_equal "/en/duels/#{@duel.token}/calls", form["action"]
    assert_equal rules.hand(:challenger).map { position_of(rules, :challenger, it).to_s }, form.css("input[name=card]").map { it["value"] }
    assert_equal Game::DuelStat::STATS.flat_map { |stat| [ "#{stat}-high", "#{stat}-low" ] }, form.css("input[name=call]").map { it["value"] }
    assert_equal [ "1" ], form.css("input[type=hidden]").map { it["value"] }
    assert_no_match(/style=/, board("challenger", :en).to_html)
  end

  test "each board carries the mover's clock: their name from the opponent's side, You from their own, in each locale" do
    travel_to Time.zone.now.change(usec: 0)
    duel = call_round(@duel)
    mover = rules_of(Game::Duel.find(duel.id)).answerer.to_s

    DuelStreamJob.perform_now([ duel.id ])

    %w[challenger opponent].each do |role|
      clock = board(role, :en).at_css("#duel-board .duel-clock")
      assert_equal "duel-clock", clock["data-controller"]
      assert_equal Time.current + 45.seconds, Time.iso8601(clock["data-duel-clock-deadline-value"])
      assert_equal Time.current, Time.iso8601(clock["data-duel-clock-server-time-value"])
      assert_equal "{seconds} s", clock["data-duel-clock-template-value"]
      assert_equal (role == mover ? "You" : (role == "challenger" ? "Hugo" : "Léa")), clock.at_css(".duel-clock__name").text.strip
      assert_equal "45 s", clock.at_css("[data-duel-clock-target=text]").text
    end
    assert_equal "Vous", board(mover, :fr).at_css(".duel-clock__name").text.strip
    assert_equal "10 secondes", board(mover, :fr).at_css(".duel-clock")["data-duel-clock-warning-value"]
    assert_equal "45\u202fs", board(mover, :fr).at_css("[data-duel-clock-target=text]").text
  ensure
    travel_back
  end

  private
    def other_role(role) = role == "challenger" ? "opponent" : "challenger"
end

require "test_helper"
require_relative "../support/live_duels"

# Every push of every duel event, from the challenge to the result and through the challenges that end unanswered:
# no seat's board or connection slot, in any locale, ever shows the other seat's hand, a call not yet answered, or a
# draw order.
class DuelStreamSecrecyTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include LiveDuels

  ROLES = %w[challenger opponent].freeze

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
  end

  def challenge = Game::ChallengeFriend.new.call(player: @lea, friend: @hugo, deck_token: deck_token_of(@lea)).value!

  def stream(duel, role, locale) = DuelStream.streamables(Game::DuelSeat.find_by!(duel_id: duel.id, role:).stream_key, locale).join(":")

  def title(card) = (@titles ||= {})[card.card_id] ||= Catalog::CardText.where(card_id: card.card_id).pick(:title)

  def copy(fragment) = Nokogiri::HTML5.fragment(fragment.to_html)

  # Pushes the duel to its seats, checks every fragment each seat got in each locale; the fragments by seat and locale.
  def push(duel, boards: true)
    DuelStreamJob.perform_now([ duel.id ], boards:)
    duel = Game::Duel.find(duel.id)
    ROLES.product(I18n.available_locales).to_h do |role, locale|
      name = stream(duel, role, locale)
      fragments = broadcasts(name).map do |message|
        Nokogiri::HTML5.fragment(Nokogiri::HTML5.fragment(ActiveSupport::JSON.decode(message)).at_css("turbo-stream template").inner_html)
      end
      pubsub_adapter.clear_messages(name)
      assert_equal boards ? 2 : 1, fragments.size, "#{duel.state} #{role} #{locale}"
      fragments.each { assert_secret(duel, role.to_sym, locale, it) }
      [ [ role, locale ], fragments ]
    end
  end

  def assert_secret(duel, role, locale, fragment)
    return assert_no_match(/(Lea|Hugo) card [A-L]/, fragment.to_html, "#{duel.state} shows a card") unless %w[active finished].include?(duel.state)

    rules = rules_of(duel)
    other = Game::DuelRules.other(role)
    beyond_their_deck = copy(fragment).tap { it.css("#duel-their-deck").each(&:remove) }.to_html
    rules.hand(other).each { assert_not_includes beyond_their_deck, title(it), "#{role} sees a card of the other hand" }
    assert_decks_in_deck_order(rules, role, other, fragment)
    assert_call_hidden(rules, role, locale, fragment)
  end

  def assert_decks_in_deck_order(rules, role, other, fragment)
    their_deck = fragment.at_css("#duel-their-deck")
    return unless their_deck

    stages = rules.deck(other).map { rules.played(other).include?(it.card_season_id) ? "played" : "to-play" }
    assert_equal stages, their_deck.css("li.duel-deck__card").map { it["class"][/duel-deck__card--(\S+)/, 1] }
    assert_empty their_deck.css("[data-card], input")
    { "#duel-my-deck" => role, "#duel-their-deck" => other }.each do |id, owner|
      assert_equal rules.deck(owner).map { title(it) }, fragment.css("#{id} .duel-deck__name").map { it.text.strip }
    end
  end

  def assert_call_hidden(rules, role, locale, fragment)
    locked = rules.pending
    return unless locked && locked.caller != role.to_s && fragment.at_css("#duel-board")

    words = I18n.t("duel_stats.directions.#{locked.stat}.#{locked.direction}", locale:)
    unrevealed = copy(fragment).tap { it.css(".duel-past, #duel-reveal").each(&:remove) }
    assert_not_includes unrevealed.to_html, words, "#{role} sees the call of round #{locked.number}"
    assert fragment.at_css("#duel-current-call.duel-table__slot--hidden")
    assert_empty fragment.css("#duel-current-call [data-called], #duel-current-call [data-direction], input[name=stat], input[name=direction]")
  end

  test "no push of any duel event shows a seat the other hand, a call not yet answered or a draw order" do
    duel = challenge
    push(duel)
    duel = Game::AcceptChallenge.new.call(player: @hugo, token: duel.token, deck_token: deck_token_of(@hugo), move_number: duel.move_number).value!
    push(duel)

    Game::DuelSeat.where(duel_id: duel.id, role: "opponent").update_all(present_until: 1.minute.ago)
    assert push(duel, boards: false).fetch([ "challenger", :en ]).sole.at_css("[data-away-until]")
    Game::DuelSeat.where(duel_id: duel.id, role: "opponent").update_all(present_until: nil)

    10.times do
      push(duel = call_round(duel))
      push(duel = answer_round(duel))
    end
    assert_equal "finished", Game::Duel.find(duel.id).state

    [ ->(open) { Game::RefuseChallenge.new.call(player: @hugo, token: open.token) },
      ->(open) { Game::CancelChallenge.new.call(player: @lea, token: open.token) },
      ->(open) { travel(61.seconds) { Game::LapseChallenge.new.call(player: @lea, token: open.token, move_number: open.move_number) } } ].each do |ending|
      unanswered = challenge
      push(unanswered)
      ending.(unanswered).value!
      push(unanswered)
    end

    published = Rails.configuration.event_store.read.to_a.map(&:class)
    assert_empty DuelStream::EVENTS - published
  end
end

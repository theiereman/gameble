require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# The duel screen's board as each seat's page renders it: the calling and answering groups, the reveal of the last
# round, the result and the rematch.
class DuelBoardTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @lea.update!(persona_name: "Léa")
    @hugo.update!(persona_name: "Hugo")
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    Game::DeckCard.pluck(:card_season_id).each { set_percentiles(it, release: 97, popularity: 20) }
    @duel = start_duel(@lea, @hugo)
    Game::Duel.where(id: @duel.id).update_all(first_caller: "challenger")
  end

  def visit_as(player, locale: :en)
    sign_in(player)
    get duel_path(locale:, token: @duel.token)
    assert_response :success
  end

  def finish
    10.times { play_round(@duel) }
    Game::Duel.find(@duel.id)
  end

  test "the caller's hand, stat and direction are three radio groups, the stat sets and the direction sets hidden until chosen" do
    visit_as(@lea)

    form = css_select("form#duel-call").first
    assert_equal [ "Your hand", "Stat", "Direction" ], form.css("fieldset > legend").map { it.text.strip }
    assert_equal 3, form.css("input[name=card]").size
    assert_equal 15, form.css("input[name=stat]").size
    assert_equal 10, form.css("input[name=direction]").size
    assert form.css("input[name=stat], input[name=direction]").all? { it["disabled"] }
    assert form.css("[data-duel-card], [data-duel-stat], [data-duel-group]").all? { it["hidden"] }
    assert_select "form#duel-call button[type=submit][aria-disabled=true]", "Call"
    assert_select "form#duel-call input[name=stat] + .visually-hidden", text: /Release, Newer than 97% of cards, /
    assert_select "form#duel-call input[name=stat] + .visually-hidden", text: /Popularity, More obscure than 80% of cards, /
  end

  test "a stat already called stays in its group, aria-disabled, its name ending already called" do
    play_round(@duel)
    play_round(@duel)
    called = Game::DuelRound.find_by!(duel_id: @duel.id, number: 1).stat

    visit_as(@lea)

    stats = css_select("form#duel-call [data-duel-card]").first.css("label")
    assert_equal 5, stats.size
    blocked = stats.select { it.at_css("input")["aria-disabled"] == "true" }
    assert_equal [ called ], blocked.map { it.at_css("input")["value"] }
    assert_match(/, already called\z/, blocked.sole.at_css(".visually-hidden").text)
    assert_equal "Already called", blocked.sole.at_css(".duel-option__note").text
  end

  test "the answerer sees the caller's card face up with its five values and a hidden call, and no stat or direction" do
    call_round(@duel)
    locked = Game::DuelRound.find_by!(duel_id: @duel.id, number: 1)
    words = I18n.t("duel_stats.directions.#{locked.stat}.#{locked.direction}", locale: :en)

    visit_as(@hugo)

    assert_select "#duel-current-call h2.duel-table__call", "Hidden call"
    assert_select "#duel-current-call .duel-table__value", 5
    assert_select "#duel-current-call .card__title", card_title(locked.caller_card_season_id)
    assert_select "form#duel-answer input[name=card]", 3
    assert_select "form#duel-answer input[name=stat], form#duel-answer input[name=direction]", 0
    assert_select "form#duel-answer button[type=submit][aria-disabled=true]", "Answer with this card"
    assert_not_includes response.body, words
    assert_select "#duel-board[data-announce='Léa has called. Their card: #{card_title(locked.caller_card_season_id)}.']"

    visit_as(@lea)
    assert_select "#duel-current-call h2.duel-table__call", words
    assert_select "#duel-board[data-announce]", 0
  end

  test "a round answered a moment ago is shown face up with its outcome, the live board hidden, and not any more after ten seconds" do
    play_round(@duel)

    visit_as(@lea)
    assert_select "#duel-reveal[data-duel-target=reveal][data-round='1']" do
      assert_select "h2#duel-reveal-heading[tabindex='-1']", text: /\ARound 1 (won|lost|drawn): /
      assert_select ".duel-reveal__card", 2
      assert_select ".duel-reveal__outcome", text: /Won|Lost|Draw/
      assert_select "button[type=button]", "Next"
    end
    assert_select "#duel-live[hidden]"

    travel 11.seconds do
      get duel_path(locale: :en, token: @duel.token)
      assert_select "#duel-reveal", 0
      assert_select "#duel-live[hidden]", 0
      assert_select "#duel-live #duel-hand"
    end
  end

  test "the finished duel: the spoken result first, ten rounds as sentences, the place of the capsule line and the rematch" do
    duel = finish
    rules = rules_of(duel)
    scores = rules.scores
    won = { challenger: "Win against", opponent: "Loss against", draw: "Draw with" }.fetch(rules.result)
    summary = /\A#{won} Hugo, #{scores[:challenger]} to #{scores[:opponent]}/

    visit_as(@lea)

    assert_select "#duel-result-heading[tabindex='-1']" do
      assert_select ".visually-hidden", text: summary
      assert_select "[aria-hidden=true]", text: /#{scores[:challenger]}.*#{scores[:opponent]}/
    end
    assert_select "#duel-capsule-line", 1
    assert_select "ol.duel-rounds > li", 10
    assert_select "ol.duel-rounds > li:first-child", text: /\ARound 1, (Léa|Hugo) calls .+: .+, \d{4}, against .+, \d{4}\. (Won|Lost|Draw)\./
    assert_select "#duel-hand", 0
    assert_select ".duel-clock", 0

    visit_as(@lea, locale: :fr)
    assert_select "#duel-result-heading .visually-hidden", text: /\A(Victoire contre|Défaite contre|Égalité avec) Hugo, \d+ à \d+/
  end

  test "the rematch posts the challenge to the same friend with the player's own deck" do
    finish

    visit_as(@lea)

    assert_select "form[action='/en/duels/challenges'][method=post]" do
      assert_select "input[name=friend][value='#{@hugo.token}']"
      assert_select "input[name=deck][value='#{deck_token_of(@lea)}']"
      assert_select "input[name=authenticity_token]", 0
      assert_select "button.button--primary[aria-label='Rematch Hugo']", "Rematch"
    end

    post duel_challenges_path(locale: :en), params: { friend: @hugo.token, deck: deck_token_of(@lea) }
    assert_redirected_to duels_path(locale: :en, friend: @hugo.token)
  end

  test "the rematch is aria-disabled with its reason when the opponent is offline, and when they are in another duel" do
    finish
    Accounts::Player.where(id: @hugo.id).update_all(reachable_until: 1.minute.ago)

    visit_as(@lea)
    assert_select "button[aria-disabled=true][aria-describedby=duel-rematch-reason][aria-label='Rematch Hugo']", "Rematch"
    assert_select "#duel-rematch-reason", "Hugo is no longer online."
    assert_select "form[action='/en/duels/challenges']", 0

    visit_as(@lea, locale: :fr)
    assert_select "#duel-rematch-reason", "Hugo n'est plus en ligne."

    Accounts::Player.where(id: @hugo.id).update_all(reachable_until: 1.day.from_now)
    admin = accounts_players(:administrator)
    befriend(@hugo, admin)
    complete_deck(admin, "Admin")
    Game::ChallengeFriend.new.call(player: @hugo, friend: admin, deck_token: deck_token_of(@hugo)).value!

    visit_as(@lea)
    assert_select "#duel-rematch-reason", "Duel in progress"
    assert_select "button[aria-disabled=true]", "Rematch"
  end

  private
    def card_title(card_season_id) = Catalog::CardText.where(card_id: card_of(card_season_id)).pick(:title)
end

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

  test "the caller picks a card of the hand in the deck list, and the call is five always-open stat rows of a lowest and a highest side" do
    visit_as(@lea)

    form = css_select("form#duel-call").first
    assert_equal 0, form.css("fieldset").size
    assert_equal 3, css_select("#duel-my-deck input[name=card][form=duel-call]").size
    sets = css_select("#duel-my-deck [data-duel-card]")
    buttons = css_select("#duel-my-deck button[data-duel-pick]")
    assert_equal 30, buttons.size
    assert_equal Game::DuelStat::STATS.flat_map { [ "#{it}:low", "#{it}:high" ] }, sets.first.css("button[data-duel-pick]").map { it["data-duel-pick"] }
    assert buttons.all? { it["aria-pressed"] == "false" && it["type"] == "button" }
    assert_equal [ nil, nil ], form.css("input[type=hidden][name=stat], input[type=hidden][name=direction]").map { it["value"] }
    assert sets.all? { it["hidden"] }
    assert_select "form#duel-call button[type=submit][aria-disabled=true]", "Call"
    assert_select "#duel-my-deck [data-duel-card] .visually-hidden", text: /Release, Newer than 97% of cards, /
    assert_select "#duel-my-deck [data-duel-card] .visually-hidden", text: /Popularity, More obscure than 80% of cards, /
  end

  test "a stat already called keeps its row in the call, with no side to press" do
    play_round(@duel)
    play_round(@duel)
    called = Game::DuelRound.find_by!(duel_id: @duel.id, number: 1).stat

    visit_as(@lea)

    rows = css_select("#duel-my-deck [data-duel-card]").first.css(".duel-call__row")
    assert_equal Game::DuelStat::STATS.map(&:to_s), rows.map { it["data-duel-stat"] }
    spent = rows.select { it["class"].include?("duel-call__row--called") }
    assert_equal [ called ], spent.map { it["data-duel-stat"] }
    assert_equal 0, spent.sole.css("button").size
    assert_equal 8, (rows.to_a - spent).sum { it.css("button").size }
  end

  test "the answerer sees the caller's card face up with its five values and a hidden call, and no stat or direction" do
    call_round(@duel)
    locked = Game::DuelRound.find_by!(duel_id: @duel.id, number: 1)
    words = I18n.t("duel_stats.directions.#{locked.stat}.#{locked.direction}", locale: :en)

    visit_as(@hugo)

    assert_select "#duel-current-call h2.duel-table__call", "Hidden call"
    assert_select ".duel-table__slots[data-mirrored]"
    assert_select "#duel-current-call .duel-table__value", 0
    assert_select "#duel-current-call .card__title", card_title(locked.caller_card_season_id)
    assert_select "#duel-my-deck input[name=card][form=duel-answer]", 3
    assert_select "form#duel-answer input[name=stat], form#duel-answer input[name=direction]", 0
    assert_select "form#duel-answer button[type=submit][aria-disabled=true]", "Answer with this card"
    assert_not_includes response.body, words
    assert_select "#duel-board[data-announce='Léa has called. Their card: #{card_title(locked.caller_card_season_id)}.']"

    visit_as(@lea)
    assert_select "#duel-current-call h2", 0
    assert_select "#duel-current-call .stat-bars__row[data-called][data-stat=?]", locked.stat
    assert_select "#duel-board[data-announce]", 0
  end

  test "a round answered a moment ago is shown face up with its outcome on the table, and not any more after five seconds" do
    Game::Duel.where(id: @duel.id).update_all(first_caller: "opponent")
    play_round(@duel)

    visit_as(@lea)
    assert_select "#duel-reveal[data-duel-target=reveal][data-round='1']" do
      assert_select "h2#duel-reveal-heading[tabindex='-1']", text: /\ARound 1 (won|lost|drawn): /
      assert_select ".duel-reveal__card", 2
      assert_select ".duel-reveal__outcome", text: /Won|Lost|Draw/
      assert_select "button[type=button]", "Next"
    end
    assert_select "#duel-live[data-revealing] #duel-table #duel-reveal"

    travel 6.seconds do
      get duel_path(locale: :en, token: @duel.token)
      assert_select "#duel-reveal", 0
      assert_select "#duel-live[data-revealing]", 0
      assert_select "#duel-live #duel-table form.duel-form"
      assert_select "#duel-table .duel-past__round:not([hidden]) .duel-past__title", text: /Round 1 \/ 10/
      assert_select "#duel-table .duel-past__round:not([hidden]) .stat-bars__row[data-called]", 2
      assert_select "#duel-table .duel-past__round:not([hidden]) button[data-history-go][disabled]", 2
    end
  end

  test "the finished duel: the spoken result first, ten rounds as sentences, no capsule line, and the rematch" do
    duel = finish
    rules = rules_of(duel)
    scores = rules.scores
    won = { challenger: "Win against", opponent: "Loss against", draw: "Draw with" }.fetch(rules.result)
    summary = /\A#{won} Hugo, #{scores[:challenger]} to #{scores[:opponent]}/

    visit_as(@lea)

    assert_select "#duel-result-heading[tabindex='-1']" do
      assert_select ".visually-hidden", text: summary
    end
    assert_select "#duel-result .duel-result__figures[aria-hidden=true]", text: /#{scores[:challenger]} – #{scores[:opponent]}/
    assert_select "#duel-result .duel-result__pip", 10
    assert_select "#duel-capsule-line", 0
    assert_select "ol.duel-rounds > li", 10
    assert_select "ol.duel-rounds > li:first-child", text: /\ARound 1, (Léa|Hugo) calls .+: .+, \d{4}, against .+, \d{4}\. (Won|Lost|Draw)\./
    assert_select "#duel-hand", 0
    assert_select ".duel-clock", 0

    visit_as(@lea, locale: :fr)
    assert_select "#duel-result-heading .visually-hidden", text: /\A(Victoire contre|Défaite contre|Égalité avec) Hugo, \d+ à \d+/
  end

  test "an active duel offers to give up, and a finished one says who did" do
    visit_as(@lea)

    assert_select "form[action='/en/duels/#{@duel.token}/forfeit'][method=post][data-turbo-confirm] button", "Give up the duel"

    Game::ForfeitDuel.new.call(player: @lea, token: @duel.token).value!
    visit_as(@hugo)

    assert_select "form.duel-forfeit", 0
    assert_select "#duel-result[data-outcome=win]"
    assert_select ".duel-result__margin", "Léa gave up the duel."
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

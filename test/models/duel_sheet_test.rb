require "test_helper"
require_relative "../support/live_duels"

class DuelSheetTest < ActiveSupport::TestCase
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @max = accounts_players(:administrator)
  end

  def sheet(friend_token: nil, gone_token: nil, player: @lea)
    DuelSheet.new(DuelLobby.new(player), decks: DeckList.new(player, locale: :en), friend_token:, gone_token:)
  end

  def create_draft(name) = Game::CreateDeck.new.call(player: @lea, name:).value!

  test "complete decks come first, the last used preselected, drafts after and never selected" do
    first = complete_deck(@lea, "Lea")
    second = complete_deck(@lea, "Max")
    draft = create_draft("Brouillon")
    befriend(@lea, @hugo)
    complete_deck(@hugo, "Hugo")
    Game::CancelChallenge.new.call(player: @lea, token: Game::ChallengeFriend.new.call(player: @lea, friend: @hugo, deck_token: second.token).value!.token).value!

    choices = sheet.deck_choices

    assert_equal [ first.token, second.token, draft.token ], choices.map(&:token)
    assert_equal [ false, true, false ], choices.map(&:selected)
    assert_equal [ false, false, true ], choices.map(&:draft?)
    assert sheet.complete_deck?
  end

  test "without a last used deck the first complete deck is chosen, and drafts alone leave no choice to make" do
    create_draft("Brouillon")
    assert_not sheet.complete_deck?
    assert_equal "You need a complete 12-card deck to challenge.", sheet.disabled_reason

    first = complete_deck(@lea, "Lea")
    assert_equal [ first.token ], sheet.deck_choices.select(&:selected).map(&:token)
  end

  test "reachable friends are the choices: the linked one preselected, one in a duel disabled" do
    befriend(@lea, @hugo)
    befriend(@lea, @max)
    complete_deck(@lea, "Lea")
    Game::DuelSeat.create!(duel: Game::Duel.create!, role: "challenger", player_id: @hugo.id, status: "seated")

    choices = sheet(friend_token: @max.token).friend_choices

    assert_equal [ @hugo.token, @max.token ].sort, choices.map { it.player.token }.sort
    assert_equal({ @hugo.token => :in_duel, @max.token => :free }, choices.to_h { [ it.player.token, it.state ] })
    assert_equal [ @max.token ], choices.select(&:selected).map { it.player.token }
    assert sheet(friend_token: @max.token).open?
    assert_not sheet.open?
  end

  test "a gone friend is listed greyed and never selected, even when it is not reachable any more" do
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    @hugo.update_columns(reachable_until: 1.minute.ago)

    choices = sheet(friend_token: @hugo.token, gone_token: @hugo.token).friend_choices

    assert_equal [ [ @hugo.token, :gone, false ] ], choices.map { [ it.player.token, it.state, it.selected ] }
    assert_not sheet(gone_token: @max.token).friend_choices.any?, "a token that is not a friend names no one"
  end

  test "the reason the challenge is disabled follows the player's state" do
    assert_equal "You need a complete 12-card deck to challenge.", sheet.disabled_reason
    complete_deck(@lea, "Lea")
    assert_equal "Add friends to challenge them.", sheet.disabled_reason

    befriend(@lea, @hugo)
    @hugo.update_columns(reachable_until: nil)
    assert_equal "No friend is online right now.", sheet.disabled_reason

    @hugo.update_columns(reachable_until: 1.day.from_now)
    assert_nil sheet.disabled_reason

    Game::DuelSeat.create!(duel: Game::Duel.create!, role: "challenger", player_id: @lea.id, status: "seated")
    assert_equal "You already have a duel in progress.", sheet.disabled_reason
  end
end

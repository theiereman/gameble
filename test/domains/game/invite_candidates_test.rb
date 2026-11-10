require "test_helper"

class InviteCandidatesTest < ActiveSupport::TestCase
  setup do
    @searcher = accounts_players(:player)
    @searcher.update!(persona_name: "Tom")
    @thor = accounts_players(:moderator)
    @thor.update!(persona_name: "Thor")
    @arthur = accounts_players(:administrator)
    @arthur.update!(persona_name: "Arthur")
  end

  def candidates(query) = Game::InviteCandidates.call(@searcher, query)

  test "a query under two characters finds nobody" do
    assert_empty candidates("t")
    assert_empty candidates(" ")
  end

  test "names starting with the query come first, the searcher and banned players never appear" do
    accounts_players(:banned).update!(persona_name: "Thorin")

    assert_equal %w[Thor Arthur], candidates("th").map { it.player.persona_name }
  end

  test "a private profile stays out of the results" do
    @thor.update!(visibility: "private")

    assert_equal %w[Arthur], candidates("th").map { it.player.persona_name }
  end

  test "each result says whether it is a friend, invited, inviting or a stranger" do
    Game::Friendship.create!(low_player_id: [ @searcher.id, @thor.id ].min, high_player_id: [ @searcher.id, @thor.id ].max)
    invitation = Game::Invitation.create!(sender_id: @arthur.id, recipient_id: @searcher.id)

    rows = candidates("th").index_by { it.player.persona_name }

    assert_equal :friend, rows["Thor"].relation
    assert_equal :invited_by, rows["Arthur"].relation
    assert_equal invitation.token, rows["Arthur"].invitation_token

    Game::Invitation.delete_all
    Game::Invitation.create!(sender_id: @searcher.id, recipient_id: @arthur.id)
    assert_equal :invited, candidates("arthur").first.relation
  end

  test "a like wildcard in the query is matched literally" do
    assert_empty candidates("t%r")
  end
end

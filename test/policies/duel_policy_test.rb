require "test_helper"

class DuelPolicyTest < ActiveSupport::TestCase
  def policy_for(role, record = :duel)
    DuelPolicy.new(role == :visitor ? nil : accounts_players(role), record)
  end

  def duel_with_seat_of(role)
    duel = Game::Duel.create!
    Game::DuelSeat.create!(duel:, role: "challenger", player_id: accounts_players(role).id, status: "seated")
    Game::DuelByToken.call(duel.token)
  end

  test "a visitor may not open the Duels screen nor challenge" do
    assert_not policy_for(:visitor).show?
    assert_not policy_for(:visitor).challenge?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may open the Duels screen and challenge a friend" do
      assert policy_for(role).show?
      assert policy_for(role).challenge?
    end
  end

  test "only a player holding a seat may open a duel and move in it" do
    duel = duel_with_seat_of(:player)

    %i[play? accept? announce? answer?].each do |query|
      assert policy_for(:player, duel).public_send(query), query
      assert_not policy_for(:moderator, duel).public_send(query), query
      assert_not policy_for(:administrator, duel).public_send(query), query
      assert_not policy_for(:visitor, duel).public_send(query), query
      assert_not policy_for(:player).public_send(query), query
    end
  end
end

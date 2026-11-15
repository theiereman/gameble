require "test_helper"

class DeckPolicyTest < ActiveSupport::TestCase
  def policy_for(role, record = :deck)
    DeckPolicy.new(role == :visitor ? nil : accounts_players(role), record)
  end

  test "a visitor may not open the editor nor make a deck" do
    %i[new? create?].each { assert_not policy_for(:visitor).public_send(it) }
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may open the editor and make a deck" do
      %i[new? create?].each { assert policy_for(role).public_send(it) }
    end
  end

  test "only its owner may open, change or delete a deck, staff included" do
    deck = Game::Deck.create!(player_id: accounts_players(:player).id, name: "Vieux briscards")

    %i[show? update? destroy?].each do |query|
      assert policy_for(:player, deck).public_send(query)
      assert_not policy_for(:moderator, deck).public_send(query)
      assert_not policy_for(:administrator, deck).public_send(query)
      assert_not policy_for(:visitor, deck).public_send(query)
      assert_not policy_for(:player).public_send(query)
    end
  end
end

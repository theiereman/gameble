require "test_helper"
require_relative "../support/custom_sets"

class CustomSetPolicyTest < ActiveSupport::TestCase
  include CustomSets

  def policy_for(role, record = :custom_set)
    CustomSetPolicy.new(role == :visitor ? nil : accounts_players(role), record)
  end

  test "a visitor may not make a set" do
    %i[new? create? picker?].each { assert_not policy_for(:visitor).public_send(it) }
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may make a set" do
      %i[new? create? picker?].each { assert policy_for(role).public_send(it) }
    end
  end

  test "only its author may open, edit or delete a set, staff included" do
    custom_set = create_custom_set(accounts_players(:player))

    %i[show? edit? update? destroy?].each do |query|
      assert policy_for(:player, custom_set).public_send(query)
      assert_not policy_for(:moderator, custom_set).public_send(query)
      assert_not policy_for(:administrator, custom_set).public_send(query)
      assert_not policy_for(:visitor, custom_set).public_send(query)
      assert_not policy_for(:player).public_send(query)
    end
  end
end

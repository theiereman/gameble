require "test_helper"

class BackOffice::ChartPublicationPolicyTest < ActiveSupport::TestCase
  def policy_for(role) = BackOffice::ChartPublicationPolicy.new(role == :visitor ? nil : accounts_players(role), %i[back_office chart_publication])

  test "only an administrator publishes or unpublishes a chart" do
    assert policy_for(:administrator).publish?
    assert policy_for(:administrator).unpublish?
    [ :visitor, :player, :moderator ].each do |role|
      assert_not policy_for(role).publish?, role
      assert_not policy_for(role).unpublish?, role
    end
  end
end

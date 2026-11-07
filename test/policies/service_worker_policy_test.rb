require "test_helper"

class ServiceWorkerPolicyTest < ActiveSupport::TestCase
  [ :visitor, :player, :moderator, :administrator ].each do |role|
    test "a #{role} may fetch the service worker" do
      player = role == :visitor ? nil : accounts_players(role)

      assert ServiceWorkerPolicy.new(player, :service_worker).show?
    end
  end
end

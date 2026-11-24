require "test_helper"

class Accounts::CreditDonorsTest < ActiveSupport::TestCase
  setup { @administrator = accounts_players(:administrator) }

  def add(name) = Accounts::AddCreditDonor.new.call(staff: @administrator, name:)
  def events(type) = Rails.configuration.event_store.read.of_type(type).count

  test "a name is cleaned, listed in order of arrival and published once" do
    assert_difference -> { events(Accounts::CreditDonorAdded) }, 2 do
      add("  Sandrine   K ").value!
      add("Brother_42").value!
    end

    assert_equal [ "Sandrine K", "Brother_42" ], Accounts::CreditDonors.names
  end

  test "an empty name, a name over the limit and a repeat in another case are refused" do
    add("Sandrine").value!

    assert_equal :invalid_credit_donor, add("   ").failure
    assert_equal :invalid_credit_donor, add("x" * (Accounts::CreditDonor::NAME_LENGTH + 1)).failure
    assert_equal :credit_donor_already_listed, add("SANDRINE").failure
    assert_equal [ "Sandrine" ], Accounts::CreditDonors.names
  end

  test "a donor is removed once and publishes the event" do
    donor = add("Sandrine").value!

    assert_difference -> { events(Accounts::CreditDonorRemoved) }, 1 do
      Accounts::RemoveCreditDonor.new.call(staff: @administrator, donor:).value!
    end
    assert_empty Accounts::CreditDonors.names
    assert_equal :credit_donor_not_found, Accounts::RemoveCreditDonor.new.call(staff: @administrator, donor: nil).failure
  end
end

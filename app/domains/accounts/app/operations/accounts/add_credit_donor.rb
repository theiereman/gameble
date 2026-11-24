module Accounts
  class AddCreditDonor < ApplicationOperation
    def call(staff:, name:)
      name = step valid(name)

      transaction do
        step not_listed(name)
        donor = CreditDonor.create!(name:)
        step publish(CreditDonorAdded.new(data: { donor_id: donor.id, staff_id: staff.id }), stream_name: CreditDonor.stream_name)
        donor
      end
    end

    private

    def valid(name)
      name = CreditDonor.clean(name)
      CreditDonor.valid_name?(name) ? Success(name) : Failure(:invalid_credit_donor)
    end

    def not_listed(name)
      CreditDonor.where("lower(name) = ?", name.downcase).exists? ? Failure(:credit_donor_already_listed) : Success()
    end
  end
end

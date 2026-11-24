module Accounts
  class RemoveCreditDonor < ApplicationOperation
    def call(staff:, donor:)
      donor = step require_donor(donor)

      transaction do
        donor.destroy!
        step publish(CreditDonorRemoved.new(data: { donor_id: donor.id, staff_id: staff.id }), stream_name: CreditDonor.stream_name)
        donor
      end
    end

    private

    def require_donor(donor)
      donor.is_a?(CreditDonor) && donor.persisted? ? Success(donor) : Failure(:credit_donor_not_found)
    end
  end
end

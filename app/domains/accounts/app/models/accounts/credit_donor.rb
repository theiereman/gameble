module Accounts
  class CreditDonor < ApplicationRecord
    self.table_name = "accounts_credit_donors"

    NAME_LENGTH = 60

    has_secure_token :token, length: 24

    scope :in_order_of_arrival, -> { order(:created_at, :id) }

    def self.stream_name
      "Accounts::CreditDonors"
    end

    def self.clean(name)
      name.to_s.gsub(/\s+/, " ").strip
    end

    def self.valid_name?(name)
      name.length.between?(1, NAME_LENGTH)
    end

    def to_param
      token
    end
  end
end

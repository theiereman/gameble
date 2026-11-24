module Accounts
  module CreditDonors
    def self.in_order_of_arrival
      CreditDonor.in_order_of_arrival.to_a
    end

    def self.names
      CreditDonor.in_order_of_arrival.pluck(:name)
    end

    def self.by_token(token)
      CreditDonor.find_by(token: token.to_s)
    end
  end
end

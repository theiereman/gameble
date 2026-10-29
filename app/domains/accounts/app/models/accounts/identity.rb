module Accounts
  class Identity < ApplicationRecord
    self.table_name = "accounts_identities"

    PROVIDERS = %w[steam discord google email].freeze

    belongs_to :player, class_name: "Accounts::Player", inverse_of: :identities

    validates :provider, inclusion: { in: PROVIDERS }
    validates :uid, presence: true
  end
end

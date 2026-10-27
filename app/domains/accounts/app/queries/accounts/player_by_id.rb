module Accounts
  module PlayerById
    def self.call(id)
      return nil if id.blank?

      Player.find_by(id: id)
    end
  end
end

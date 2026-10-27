module Steam
  # Reads one import run by its public token, for the back-office (AD-3,
  # AD-15). Nil when absent.
  module ImportRunByToken
    def self.call(token)
      return nil if token.blank?

      ImportRun.find_by(token: token.to_s)
    end
  end
end

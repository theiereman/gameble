module Steam
  module ImportRunByToken
    def self.call(token)
      return nil if token.blank?

      ImportRun.find_by(token: token.to_s)
    end
  end
end

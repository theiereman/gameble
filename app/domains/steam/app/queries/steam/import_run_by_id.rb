module Steam
  module ImportRunById
    def self.call(id)
      ImportRun.find_by(id: id)
    end
  end
end

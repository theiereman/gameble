module Game
  module DuelsById
    def self.call(ids)
      Duel.includes(:seats, :rounds).where(id: ids).order(:id).to_a
    end
  end
end

module Game
  module Market
    module EconomySeries
      RarityPrices = Data.define(:days, :days_of_income, :index) do
        def self.of(days, days_of_income)
          new(days:, days_of_income:, index: days_of_income.transform_values { indexed(it) })
        end

        def self.indexed(values)
          base = values.compact.first
          values.map { (it * 100 / base).round(1) if it && base&.positive? }
        end
        private_class_method :indexed

        def rarities = days_of_income.keys

        def empty? = days_of_income.values.all? { it.none? }

        def last_days_of_income(rarity) = days_of_income.fetch(rarity).compact.last

        def last_index(rarity) = index.fetch(rarity).compact.last

        def change_basis_points(rarity)
          priced = days_of_income.fetch(rarity).compact
          return if priced.size < 2 || !priced.first.positive?

          ((priced.last - priced.first) * 10_000 / priced.first).round
        end

        def highest_index_rarity = rarities.select { last_index(it) }.max_by { last_index(it) }
      end
    end
  end
end

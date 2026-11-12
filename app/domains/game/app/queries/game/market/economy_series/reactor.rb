module Game
  module Market
    module EconomySeries
      Reactor = Data.define(:days, :minted, :destroyed, :balance, :circulation) do
        def self.of(days, snapshots)
          rows = snapshots.values_at(*days)
          new(
            days:,
            minted: rows.map { it&.created },
            destroyed: rows.map { it&.destroyed_total },
            balance: rows.map { it && (it.created - it.destroyed_total) },
            circulation: rows.map { it&.circulation }
          )
        end

        def empty? = circulation.none?

        def last_circulation = circulation.compact.last

        def minted_total = (minted.compact.sum unless empty?)

        def destroyed_total = (destroyed.compact.sum unless empty?)

        def destroyed_share_basis_points
          (destroyed_total * 10_000).div(minted_total) if minted_total&.positive?
        end
      end
    end
  end
end

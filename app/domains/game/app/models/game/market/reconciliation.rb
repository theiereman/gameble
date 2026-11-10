module Game
  module Market
    # What one nightly read found: the wallets that disagree with their entries, and the all-time totals.
    Reconciliation = Data.define(:wallet_differences, :minted, :destroyed, :circulation, :read_at) do
      def circulation_difference = circulation - (minted - destroyed)

      def balanced? = wallet_differences.empty? && circulation_difference.zero?
    end

    Reconciliation::WalletDifference = Data.define(:player_id, :wallet_available, :wallet_committed, :entries_available, :entries_committed)

    class Reconciliation::WalletMismatch < StandardError; end
    class Reconciliation::CirculationMismatch < StandardError; end
  end
end

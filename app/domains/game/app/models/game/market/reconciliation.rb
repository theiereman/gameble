module Game
  module Market
    # What one nightly read found: the wallets that disagree with their entries, the all-time totals and, when asked, the circulation at a cutoff.
    Reconciliation = Data.define(:wallet_differences, :minted, :destroyed, :circulation, :read_at, :circulation_before_cutoff) do
      def initialize(circulation_before_cutoff: nil, **) = super

      def circulation_difference = circulation - (minted - destroyed)

      def balanced? = wallet_differences.empty? && circulation_difference.zero?
    end

    Reconciliation::WalletDifference = Data.define(:player_id, :wallet_available, :wallet_committed, :entries_available, :entries_committed)

    class Reconciliation::WalletMismatch < StandardError; end
    class Reconciliation::CirculationMismatch < StandardError; end
  end
end

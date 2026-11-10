module Game
  class ReconcileWalletsJob < ActiveJob::Base
    queue_as :default

    def perform(now: Time.current)
      reconciliation = Market::ReconcileWallets.call
      report(reconciliation)
      Market::RefreshEditionPrices.new.call(now:).value!
      reconciliation
    end

    private

    def report(reconciliation)
      reconciliation.wallet_differences.each { report_wallet(it) }
      report_circulation(reconciliation) unless reconciliation.circulation_difference.zero?
    end

    def report_wallet(difference)
      Rails.error.report(Market::Reconciliation::WalletMismatch.new("wallet #{difference.player_id} differs from its ledger entries"),
        handled: true, context: difference.to_h)
    end

    def report_circulation(reconciliation)
      Rails.error.report(Market::Reconciliation::CirculationMismatch.new("circulation differs from minted less destroyed"),
        handled: true, context: reconciliation.to_h.slice(:circulation, :minted, :destroyed).merge(difference: reconciliation.circulation_difference))
    end
  end
end

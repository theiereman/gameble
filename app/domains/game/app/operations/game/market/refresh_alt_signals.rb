module Game
  module Market
    # Replaces every alt-account signal with what AltSignals detects now, in one transaction and with no event: it writes no account, trade or holding.
    class RefreshAltSignals < ApplicationOperation
      def call(now: Time.current)
        detected = AltSignals.call(now:)

        transaction do
          AltSignal.delete_all
          AltSignal.insert_all!(detected.map { row(it, now) }) unless detected.empty?
        end
        detected.size
      end

      private

      def row(signal, now)
        { account_id: signal.account_id, signal: signal.signal, other_account_id: signal.other_account_id, facts: signal.facts, refreshed_at: now }
      end
    end
  end
end

module Game
  module Market
    # The signals staff read, each with the accounts it names, in the order of the signals and then of the account's persona name.
    module AltSignalRows
      Row = Data.define(:signal, :account, :other_account, :facts)

      def self.call
        rows = AltSignal.includes(:account, :other_account).to_a
        rows.sort_by { [ AltSignals::SIGNALS.index(it.signal), it.account.persona_name.to_s.downcase, it.id ] }
          .map { Row.new(signal: it.signal, account: it.account, other_account: it.other_account, facts: it.facts) }
      end

      def self.refreshed_at = AltSignal.maximum(:refreshed_at)
    end
  end
end

module Game
  module Market
    class RefreshAltSignals < ApplicationOperation
      def call(now: Time.current)
        detected = AltSignals.call(now:)
        ties = ties(detected, now)

        transaction do
          AltSignal.delete_all
          AltSignal.insert_all!(detected.map { row(it, now) }) unless detected.empty?
          TiedAccount.delete_all
          TiedAccount.insert_all!(ties) unless ties.empty?
        end
        detected.size
      end

      private

      def row(signal, now)
        { account_id: signal.account_id, signal: signal.signal, other_account_id: signal.other_account_id, facts: signal.facts, refreshed_at: now }
      end

      def ties(detected, now)
        tying = detected.select { AltSignals::TYING.include?(it.signal) }
        tying.group_by { [ it.pair, it.signal ] }.map do |(pair, signal), both_ways|
          facts = both_ways.map(&:facts).reduce { |one, other| one.merge(other) { |_, a, b| a + b } }
          { low_account_id: pair.first, high_account_id: pair.last, signal:, facts:, refreshed_at: now }
        end
      end
    end
  end
end

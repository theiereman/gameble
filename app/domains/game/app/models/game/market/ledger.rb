module Game
  module Market
    # The only writer of wallets and ledger entries. Call it once per transaction, after every other lock.
    module Ledger
      Entry = Data.define(:player_id, :kind, :available_delta, :committed_delta, :listing_id, :settings_id) do
        def initialize(player_id:, kind:, available_delta: 0, committed_delta: 0, listing_id: nil, settings_id:)
          raise ArgumentError, "unknown ledger kind: #{kind.inspect}" unless LedgerEntry::KINDS.include?(kind.to_s)

          super(kind: kind.to_s, player_id:, available_delta:, committed_delta:, listing_id:, settings_id:)
        end
      end

      def self.post(entries)
        entries = Array(entries)
        return if entries.empty?

        now = Time.current
        net = entries.group_by(&:player_id).sort.to_h { |player_id, own| [ player_id, [ own.sum(&:available_delta), own.sum(&:committed_delta) ] ] }
        create_missing_wallets(net.keys, now)
        Wallet.where(player_id: net.keys).order(:player_id).lock.pluck(:id)
        net.each do |player_id, (available, committed)|
          Wallet.where(player_id:).update_all([ "available = available + ?, committed = committed + ?, updated_at = ?", available, committed, now ])
        end
        LedgerEntry.insert_all!(entries.map { |entry| entry.to_h.merge(created_at: now) }, record_timestamps: false)
      end

      def self.create_missing_wallets(player_ids, now)
        Wallet.insert_all(player_ids.map { |player_id| { player_id:, created_at: now, updated_at: now } }, unique_by: :player_id, record_timestamps: false)
      end
      private_class_method :create_missing_wallets
    end
  end
end

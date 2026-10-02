module Game
  # Tops a player's bank back up to Pack::BANK_SIZE unopened regular packs
  # (CAP-4, AD-7): a step of the operations that change the bank, run under
  # the bank lock (Game::BankLock) inside their transaction.
  #
  # Each missing pack is drawn at once from the in-memory pool (regular odds,
  # the season published now) and scheduled Pack::INTERVAL after the later of
  # `now` and the latest availability time in the bank, that time recomputed
  # after each pack. With a full bank before an opening, this is AD-7's rule:
  # ten minutes after the latest time in the bank, or after the opening when
  # every pack was available. A bank left short heals the same way.
  #
  # Drawn inline rather than by a job: a recorded deviation from AD-7
  # (pending-approvals.md). Bonus and reward packs neither count nor move
  # the schedule. With no published season, nothing is inserted.
  #
  #   Game::TopUpBank.call(player_id: player.id, now: Time.current) # => packs inserted
  module TopUpBank
    def self.call(player_id:, now:, random: SecureRandom)
      bank = Pack.bank(player_id)
      missing = Pack::BANK_SIZE - bank.count
      return 0 unless missing.positive?

      pool = DrawPool.current
      return 0 if pool.nil?

      start = [ now, bank.maximum(:available_at) ].compact.max
      Pack.insert_all!(Array.new(missing) do |index|
        { player_id:, token: Pack.generate_unique_secure_token, kind: "regular", season_id: pool.season_id,
          card_season_ids: Draw.pack(odds: DrawOdds::REGULAR, size: Pack::SIZE, random:, pool:),
          available_at: start + (Pack::INTERVAL * (index + 1)) }
      end)
      missing
    end
  end
end

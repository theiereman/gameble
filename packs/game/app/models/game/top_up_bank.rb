module Game
  # Puts regular packs into a player's bank (CAP-4, AD-7): a step of the
  # operations that change the bank, run under the bank lock
  # (Game::BankLock) inside their transaction. Each pack is drawn at once
  # from the in-memory pool (regular odds, the season published now).
  #
  # `call`, after an opening (Game::OpenPack): the opened pack is replaced,
  # one pack, scheduled Pack::INTERVAL after the later of `now` and the
  # latest availability time in the bank. With a full bank before the
  # opening, this is AD-7's rule: ten minutes after the latest time in the
  # bank, or after the opening when every pack was available. A bank short
  # of ten before the opening stays short by as much: an opening never fills
  # it (no fill on use).
  #
  # `heal`, when a season is published (Game::HealBank, through
  # Game::HealBanksJob): every pack missing from ten is inserted, all
  # available at `now`, at once. Nothing else heals a bank (author,
  # 2026-10-07).
  #
  # Drawn inline rather than by a job: a recorded deviation from AD-7
  # (pending-approvals.md). Bonus and reward packs neither count nor move
  # the schedule. With no published season, nothing is inserted.
  #
  #   Game::TopUpBank.call(player_id: player.id, now: Time.current, pool:) # => packs inserted, 0 or 1
  #   Game::TopUpBank.heal(player_id: player.id, now: Time.current) # => packs inserted, 0 to 10
  module TopUpBank
    def self.call(player_id:, now:, pool: DrawPool.current, random: SecureRandom)
      bank = Pack.bank(player_id)
      return 0 unless bank.count < Pack::BANK_SIZE

      start = [ now, bank.maximum(:available_at) ].compact.max
      insert(player_id, [ start + Pack::INTERVAL ], random, pool)
    end

    def self.heal(player_id:, now:, random: SecureRandom)
      missing = Pack::BANK_SIZE - Pack.bank(player_id).count
      return 0 unless missing.positive?

      insert(player_id, [ now ] * missing, random, DrawPool.current)
    end

    # One regular pack per availability time, in one statement; 0 with no
    # published season.
    def self.insert(player_id, times, random, pool)
      return 0 if pool.nil?

      Pack.insert_all!(times.map do |available_at|
        Pack.row(player_id:, kind: :regular, season_id: pool.season_id,
          card_season_ids: Draw.pack(odds: DrawOdds::REGULAR, size: Pack::SIZE, random:, pool:), available_at:)
      end)
      times.size
    end
    private_class_method :insert
  end
end

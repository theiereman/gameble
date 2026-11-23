module Game
  module Market
    # One copy a player bought from the Archives. Players are anonymised, never deleted, so a withdrawal outlives its account.
    class ArchiveWithdrawal < ApplicationRecord
      self.table_name = "game_market_archive_withdrawals"

      PURCHASE_TOKEN_FORMAT = /\A[1-9A-HJ-NP-Za-km-z]{24}\z/
    end
  end
end

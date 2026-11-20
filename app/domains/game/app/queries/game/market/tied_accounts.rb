module Game
  module Market
    module TiedAccounts
      def self.call(player)
        pairs = TiedAccount.where(low_account_id: player.id).or(TiedAccount.where(high_account_id: player.id)).pluck(:low_account_id, :high_account_id)
        pairs.flatten.uniq - [ player.id ]
      end
    end
  end
end

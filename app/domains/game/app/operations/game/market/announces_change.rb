module Game
  module Market
    # Shows a change of the market on the announcement banner, replacing the one shown; a refused announcement halts the whole operation.
    module AnnouncesChange
      private

      def announce(player, message_fr, message_en)
        step Accounts::CreateAnnouncement.new.call(staff: player, message_fr:, message_en:, shown: true)
      end
    end
  end
end

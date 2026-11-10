module Game
  module Market
    # What happened on a listing that its Annonce shows apart from the history, for one viewer.
    module AnnonceEvents
      Outbid = Data.define(:other, :amount)
      Events = Data.define(:outbid)

      NONE = Events.new(outbid: nil)

      def self.call(token:, viewer:)
        listing = Listing.where(token: token.to_s, status: "open").select(:id, :leader_id).first
        return NONE unless listing

        Events.new(outbid: outbid(listing, viewer))
      end

      def self.outbid(listing, viewer)
        return if viewer.nil? || listing.leader_id == viewer.id

        notice = Notice.find_by(player_id: viewer.id, listing_id: listing.id, kind: "outbid")
        Outbid.new(other: notice.other_player, amount: notice.amount) if notice&.other_player
      end

      private_class_method :outbid
    end
  end
end

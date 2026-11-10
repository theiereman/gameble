module Game
  module Market
    # What happened on a listing that its Annonce shows apart from the history, for one viewer.
    module AnnonceEvents
      Outbid = Data.define(:other, :amount)
      Extended = Data.define(:until, :minutes)
      Events = Data.define(:outbid, :extended)

      NONE = Events.new(outbid: nil, extended: nil)

      SECONDS_PER_MINUTE = 60

      def self.call(token:, viewer:)
        listing = Listing.where(token: token.to_s, status: "open").select(:id, :leader_id, :ends_at, :settings_id).first
        return NONE unless listing

        Events.new(outbid: outbid(listing, viewer), extended: extended(listing))
      end

      def self.outbid(listing, viewer)
        return if viewer.nil? || listing.leader_id == viewer.id

        notice = Notice.find_by(player_id: viewer.id, listing_id: listing.id, kind: "outbid")
        Outbid.new(other: notice.other_player, amount: notice.amount) if notice&.other_player
      end

      def self.extended(listing)
        latest = Bid.where(listing_id: listing.id).where.not(extended_until: nil).order(id: :desc).pick(:extended_until)
        return unless latest == listing.ends_at

        Extended.new(until: latest, minutes: Settings.find(listing.settings_id).soft_close_seconds / SECONDS_PER_MINUTE)
      end

      private_class_method :outbid, :extended
    end
  end
end

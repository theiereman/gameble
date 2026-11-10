module Game
  module Market
    module OldestDueListing
      def self.call(now: Time.current)
        ends_at = Listing.due(now).minimum(:ends_at)
        (now - ends_at).to_i if ends_at
      end
    end
  end
end

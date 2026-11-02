module Game
  # A feed entry by its token, when the viewer may see it as the feed lists it.
  module VisibleFeedEntry
    def self.call(viewer, token)
      return nil unless token.is_a?(String) && token.present?

      entry = FeedEntry.find_by(token:)
      return nil unless entry

      owner_ids = [ entry.player_id, entry.partner_id ].compact
      owners = Accounts::Player.where(id: owner_ids).index_by(&:id)
      entry if owner_ids.all? { Visibility.visible?(viewer, owners[it], staff_sees_all: false) }
    end
  end
end

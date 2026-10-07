module Game
  # The activity feed's entries for a viewer (CAP-13, AD-11, AD-13): the
  # newest notable pulls first, each only if Game::Visibility lets `viewer`
  # (nil for a signed-out visitor) see the player it names. When fewer than
  # MIN notable entries show, the newest fillers complete the list so the
  # feed is not empty while any activity exists (R4). Reads only.
  #
  #   Game::FeedEntries.call(nil)
  #   # => [ Entry(entry, player, filler), … ] newest first
  module FeedEntries
    Entry = Data.define(:entry, :player, :filler)

    # Entries shown, and the count under which fillers are added; both tuned in play.
    LIMIT = 30
    MIN = 10

    # Rows read per pass, as hidden players leave gaps.
    WINDOW = 90

    def self.call(viewer)
      notable = visible(FeedEntry.where(notable: true), viewer, LIMIT, filler: false)
      return notable if notable.size >= MIN

      fillers = visible(FeedEntry.where(notable: false), viewer, MIN - notable.size, filler: true)
      (notable + fillers).sort_by { |item| [ item.entry.occurred_at, item.entry.id ] }.reverse
    end

    def self.visible(scope, viewer, limit, filler:)
      entries = scope.newest_first.limit(WINDOW).to_a
      players = Accounts::Player.where(id: entries.map(&:player_id).uniq).index_by(&:id)
      entries.filter_map do |entry|
        player = players[entry.player_id]
        Entry.new(entry:, player:, filler:) if Visibility.visible?(viewer, player)
      end.first(limit)
    end
    private_class_method :visible
  end
end

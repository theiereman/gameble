module Game
  # The activity feed's entries for a viewer: the newest notable entries
  # first, of one kind when `kind` is given (the type filters; a list of
  # kinds gets no filler), of the `players` ids only when given (the friends
  # tab), each only if Game::Visibility lets `viewer` (nil for a signed-out
  # visitor) see the player it names as a player would: staff read the
  # community's stream as the community does. When fewer than MIN notable
  # entries show, the newest fillers complete the list so the feed is not
  # empty while any activity exists; fillers are pulls, so only the whole
  # feed and the pulls get them. Reads only.
  #
  #   Game::FeedEntries.call(nil)
  #   Game::FeedEntries.call(viewer, kind: "trade")
  #   Game::FeedEntries.call(viewer, players: friend_ids)
  #   # => [ Entry(entry, player, filler), … ] newest first
  module FeedEntries
    Entry = Data.define(:entry, :player, :filler)

    # Entries shown, and the count under which fillers are added; both tuned in play.
    LIMIT = 30
    MIN = 10

    # Rows read per pass, and the passes at most, as hidden players leave
    # gaps: a crowd of hidden entries does not hide older visible ones.
    WINDOW = 90
    PASSES = 10

    def self.call(viewer, kind: nil, players: nil)
      entries = players ? FeedEntry.where(player_id: players) : FeedEntry.all
      scope = kind ? entries.where(kind:) : entries
      notable = visible(scope.where(notable: true), viewer, LIMIT, filler: false)
      return notable if notable.size >= MIN || !(kind.nil? || kind == "pull")

      fillers = visible(entries.where(kind: "pull", notable: false), viewer, MIN - notable.size, filler: true)
      (notable + fillers).sort_by { |item| [ item.entry.occurred_at, item.entry.id ] }.reverse
    end

    # Reads `scope` newest first, WINDOW rows at a time after the last row
    # read, until `limit` visible entries are found or the rows run out.
    def self.visible(scope, viewer, limit, filler:)
      found = []
      players = {}
      # Asked once per player: a friends-only player costs a friendship query.
      shown = Hash.new { |seen, id| seen[id] = Visibility.visible?(viewer, players[id], staff_sees_all: false) }
      cursor = nil
      PASSES.times do
        page = scope.newest_first
        page = page.where("(game_feed_entries.occurred_at, game_feed_entries.id) < (?, ?)", *cursor) if cursor
        entries = page.limit(WINDOW).to_a
        missing = entries.map(&:player_id).uniq - players.keys
        players.merge!(Accounts::Player.where(id: missing).index_by(&:id)) if missing.any?
        entries.each do |entry|
          player = players[entry.player_id]
          found << Entry.new(entry:, player:, filler:) if shown[entry.player_id]
        end
        break if found.size >= limit || entries.size < WINDOW

        cursor = [ entries.last.occurred_at, entries.last.id ]
      end
      found.first(limit)
    end
    private_class_method :visible
  end
end

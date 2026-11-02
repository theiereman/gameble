module Game
  module FeedEntries
    Entry = Data.define(:entry, :player, :partner, :filler, :player_title, :partner_title) do
      def initialize(entry:, player:, filler:, partner: nil, player_title: nil, partner_title: nil) = super
    end

    LIMIT = 30
    MIN = 10

    WINDOW = 90
    PASSES = 10

    Page = Data.define(:items, :more) do
      def cursor = more ? [ items.last.entry.occurred_at, items.last.entry.id ] : nil
    end

    def self.call(viewer, kind: nil, players: nil)
      page(viewer, kind:, players:).items
    end

    def self.page(viewer, kind: nil, players: nil, after: nil)
      found = listed(viewer, kind:, players:, after:)
      Page.new(items: titled(found.first(LIMIT)), more: found.size > LIMIT)
    end

    def self.listed(viewer, kind:, players:, after:)
      entries = players ? FeedEntry.where(player_id: players).or(FeedEntry.where(partner_id: players)) : FeedEntry.all
      scope = kind ? entries.where(kind:) : entries
      notable = visible(scope.where(notable: true), viewer, LIMIT + 1, filler: false, after:)
      return notable if after || notable.size >= MIN || !(kind.nil? || kind == "pull")

      fillers = visible(entries.where(kind: "pull", notable: false), viewer, MIN - notable.size, filler: true)
      (notable + fillers).sort_by { |item| [ item.entry.occurred_at, item.entry.id ] }.reverse
    end

    private_class_method :listed

    def self.titled(items)
      titles = ActiveProfileTitle.for_players(items.flat_map { [ it.player, it.partner ] }.compact.uniq)
      items.map { it.with(player_title: titles[it.player.id], partner_title: (titles[it.partner.id] if it.partner)) }
    end
    private_class_method :titled

    def self.visible(scope, viewer, limit, filler:, after: nil)
      found = []
      players = {}
      shown = Hash.new { |seen, id| seen[id] = Visibility.visible?(viewer, players[id], staff_sees_all: false) }
      cursor = after
      PASSES.times do
        page = scope.newest_first
        page = page.where("(game_feed_entries.occurred_at, game_feed_entries.id) < (?, ?)", *cursor) if cursor
        entries = page.limit(WINDOW).to_a
        missing = entries.flat_map { [ it.player_id, it.partner_id ] }.compact.uniq - players.keys
        players.merge!(Accounts::Player.where(id: missing).index_by(&:id)) if missing.any?
        entries.each do |entry|
          next unless shown[entry.player_id] && (entry.partner_id.nil? || shown[entry.partner_id])

          found << Entry.new(entry:, player: players[entry.player_id], partner: players[entry.partner_id], filler:)
        end
        break if found.size >= limit || entries.size < WINDOW

        cursor = [ entries.last.occurred_at, entries.last.id ]
      end
      found.first(limit)
    end
    private_class_method :visible
  end
end

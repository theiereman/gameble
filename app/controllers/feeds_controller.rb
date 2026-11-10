class FeedsController < ApplicationController
  FILTERS = { "pulls" => "pull", "discoveries" => "discovery", "trades" => "trade", "reposts" => "repost", "sales" => "sale" }.freeze

  TABS = %w[friends].freeze

  def show
    authorize :page, :show?
    @filter = params[:filter].presence_in(FILTERS.keys)
    @tab = params[:tab].presence_in(TABS) if current_player
    friend_ids = Game::FriendsOf.call(current_player).map(&:id) if @tab
    @no_friends = friend_ids&.empty?
    @after = FeedCursor.decode(params[:cursor])
    @before = FeedCursor.decode(params[:newer]) unless @after
    @target = jump_target
    newer, older = @no_friends ? [] : feed_pages(players: friend_ids)
    @live = @tab.nil? && @filter.nil? && @after.nil? && newer.nil?
    @items = FeedItems.call([ newer, older ].compact.flat_map(&:items))
    @reactions = Game::FeedReactionSummaries.call(@items.map { |item, *| item.entry.id }, viewer: current_player)
    @next_cursor = encode(older ? older.cursor : last_position(newer))
    @newer_cursor = encode(newer&.cursor)
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private
    def feed_pages(players:)
      return [ newer_page(players:, before: @before), nil ] if @before

      first = older_page(players:, after: @after)
      return [ nil, first ] unless @target && first.more && first.items.none? { it.entry.id == @target.id }

      position = Game::FeedEntries.position(@target)
      [ newer_page(players:, before: position), older_page(players:, from: position) ]
    end

    def older_page(players:, **bound)
      Game::FeedEntries.page(current_player, kind: FILTERS[@filter], players:, **bound)
    end

    def newer_page(players:, before:)
      Game::FeedEntries.newer(current_player, kind: FILTERS[@filter], players:, before:)
    end

    def encode(position) = position && FeedCursor.encode(position)

    def last_position(page)
      Game::FeedEntries.position(page.items.last.entry) if page&.items&.any?
    end

    def jump_target
      return if @after || @before

      Game::VisibleFeedEntry.call(current_player, params[:entry])
    end
end

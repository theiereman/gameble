class FeedsController < ApplicationController
  FILTERS = { "pulls" => "pull", "discoveries" => "discovery", "trades" => "trade", "reposts" => "repost" }.freeze

  TABS = %w[friends].freeze

  def show
    authorize :page, :show?
    @filter = params[:filter].presence_in(FILTERS.keys)
    @tab = params[:tab].presence_in(TABS) if current_player
    friend_ids = Game::FriendsOf.call(current_player).map(&:id) if @tab
    @no_friends = friend_ids&.empty?
    @after = FeedCursor.decode(params[:cursor])
    @live = @tab.nil? && @filter.nil? && @after.nil?
    page = @no_friends ? nil : feed_page(players: friend_ids)
    @items = page ? FeedItems.call(page.items) : []
    @reactions = Game::FeedReactionSummaries.call(@items.map { |item, *| item.entry.id }, viewer: current_player)
    @next_cursor = FeedCursor.encode(page.cursor) if page&.more
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private
    def feed_page(players:)
      Game::FeedEntries.page(current_player, kind: FILTERS[@filter], players:, after: @after)
    end
end

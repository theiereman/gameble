# The activity feed: the notable entries, newest first, readable without an
# account, under the All and Friends tabs and the type filters Everything,
# Pulls, Discoveries, Trades and Reposts; a tab and a filter combine. A read
# only page: Game answers the entries each already filtered by
# Game::Visibility for the viewer, Catalog the cards. All without a filter
# listens to the public live stream for new entries.
class FeedsController < ApplicationController
  # The `filter` parameter's values and the kind of entry each shows; none,
  # or an unknown one, is the whole feed.
  FILTERS = { "pulls" => "pull", "discoveries" => "discovery", "trades" => "trade", "reposts" => "repost" }.freeze

  TABS = %w[friends].freeze

  # GET /:locale/feed(?tab=friends)(&filter=pulls)
  def show
    authorize :page, :show?
    @filter = params[:filter].presence_in(FILTERS.keys)
    @tab = params[:tab].presence_in(TABS) if current_player
    friend_ids = Game::FriendsOf.call(current_player).map(&:id) if @tab
    @no_friends = friend_ids&.empty?
    @live = @tab.nil? && @filter.nil?
    @items = @no_friends ? [] : items(players: friend_ids)
  end

  private
    def items(players:)
      FeedItems.call(Game::FeedEntries.call(current_player, kind: FILTERS[@filter], players:))
    end
end

class FeedsController < ApplicationController
  FILTERS = { "pulls" => "pull", "discoveries" => "discovery", "trades" => "trade", "reposts" => "repost" }.freeze

  TABS = %w[friends].freeze

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

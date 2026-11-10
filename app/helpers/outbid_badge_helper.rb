module OutbidBadgeHelper
  def shell_outbid_count
    return @shell_outbid_count if defined?(@shell_outbid_count)

    @shell_outbid_count = shell_balance ? Game::Market::OutbidCount.call(current_player) : 0
  end
end

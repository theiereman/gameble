class PlayerStreamJob < ApplicationJob
  queue_as :default

  def perform(notices)
    notices.group_by { it[:player_id] }.each do |player_id, own|
      player = Accounts::PlayerById.call(player_id)
      next unless reachable?(player)

      topics = own.filter_map { it[:topic] }.uniq
      invitations_changed = topics.include?("friends")
      rewards_changed = own.any? { it[:achievement] || it[:claimed] }
      locals = {
        waiting: (Game::TradesWaiting.call(player) if topics.include?("trades")),
        invitations: (Game::InvitationsWaiting.call(player) if invitations_changed),
        friends: announceable_friends(own.filter_map { it[:friend_id] }),
        unclaimed: (Game::UnclaimedAchievements.count(player) if rewards_changed),
        balance: (Game::Market::Balance.call(player) if own.any? { it[:balance] }),
        outbid: (Game::Market::OutbidCount.call(player) if topics.include?("market")),
        pending: (pending_for(player) if invitations_changed || rewards_changed),
        achievements: own.filter_map { it[:achievement] }.uniq,
        card_backs: own.filter_map { it[:card_back] }.uniq,
        signals: topics.map { "#{it}-updated" }
      }
      outbid_listings = own.filter_map { it[:outbid_listing_id] }.uniq
      I18n.available_locales.each { broadcast(player, it, locals.merge(outbid_lines: outbid_lines(player, it, outbid_listings))) }
    end
  end

  private

  def pending_for(player)
    Game::InvitationsWaiting.call(player) + Game::UnclaimedAchievements.count(player)
  end

  def outbid_lines(player, locale, listing_ids)
    return [] if listing_ids.empty?

    Game::Market::MarketNotices.outbid(player:, listing_ids:, locale:)
  end

  def reachable?(player)
    player.present? && !player.removed?
  end

  def announceable_friends(ids)
    return [] if ids.empty?

    Accounts::Player.in_good_standing.where(id: ids).order(:id).to_a
  end

  def broadcast(player, locale, locals)
    content = I18n.with_locale(locale) do
      ApplicationController.render(partial: "player_streams/update", formats: [ :turbo_stream ], locals:)
    end
    Turbo::StreamsChannel.broadcast_stream_to(*PlayerStream.streamables(player, locale), content:)
  end
end

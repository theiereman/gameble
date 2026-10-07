class PlayerStreamJob < ApplicationJob
  queue_as :default

  def perform(notices)
    notices.group_by { it[:player_id] }.each do |player_id, own|
      player = Accounts::PlayerById.call(player_id)
      next unless reachable?(player)

      topics = own.map { it[:topic] }.uniq
      locals = {
        waiting: (Game::TradesWaiting.call(player) if topics.include?("trades")),
        friends: announceable_friends(own.filter_map { it[:friend_id] }),
        signals: topics.map { "#{it}-updated" }
      }
      I18n.available_locales.each { broadcast(player, it, locals) }
    end
  end

  private

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

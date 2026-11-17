class DuelSeatChannel < Turbo::StreamsChannel
  periodically :note_presence, every: 10.seconds

  def subscribed
    name = verified_stream_name_from_params
    if name && own_seat?(name)
      stream_from name
      note_presence(refresh: true)
    else
      reject
    end
  end

  private

  def own_seat?(name)
    _, key, locale = name.split(":", 3)
    current_player.present? && I18n.available_locales.map(&:to_s).include?(locale) &&
      DuelStream.streamables(key, locale).join(":") == name && Game::DuelSeatHolder.call(key) == current_player.id
  end

  def note_presence(refresh: false)
    return if subscription_rejected?

    presence = Game::NoteDuelPresence.new.call(stream_key: verified_stream_name_from_params.split(":", 3).second).value!
    DuelStreamJob.perform_later([ presence.duel_id ]) if presence && (refresh || presence.lapsed)
  end
end

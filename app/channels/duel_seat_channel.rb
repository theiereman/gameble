class DuelSeatChannel < Turbo::StreamsChannel
  def subscribed
    name = verified_stream_name_from_params
    if name && own_seat?(name)
      stream_from name
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
end

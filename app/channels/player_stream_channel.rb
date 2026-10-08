class PlayerStreamChannel < Turbo::StreamsChannel
  def subscribed
    name = verified_stream_name_from_params
    if name && own_stream?(name)
      stream_from name
    else
      reject
    end
  end

  private

  def own_stream?(name)
    current_player.present? && PlayerStream.names(current_player).include?(name)
  end
end

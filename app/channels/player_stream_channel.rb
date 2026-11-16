class PlayerStreamChannel < Turbo::StreamsChannel
  RENEWAL = 30.seconds

  periodically :note_reachable, every: RENEWAL

  def subscribed
    name = verified_stream_name_from_params
    if name && own_stream?(name)
      stream_from name
      note_reachable
    else
      reject
    end
  end

  private

  def own_stream?(name)
    current_player.present? && PlayerStream.names(current_player).include?(name)
  end

  def note_reachable
    Accounts::NoteReachable.new.call(player_id: current_player.id) if current_player && !subscription_rejected?
  end
end

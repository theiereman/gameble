module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_player

    def connect
      player = Accounts::PlayerById.call(request.session[:player_id])
      reject_unauthorized_connection if player&.removed?
      self.current_player = player
    end
  end
end

module Game
  class PracticeBotJob < ActiveJob::Base
    queue_as :duels

    def perform(token, move_number)
      duel = Duel.includes(:seats).find_by(token:, practice: true)
      bot_id = duel&.seats&.find { it.role == PracticeBot::ROLE.to_s }&.player_id
      bot = Accounts::Player.find_by(id: bot_id)
      PlayPracticeMove.new.call(player: bot, token:, move_number:) if bot
    end
  end
end

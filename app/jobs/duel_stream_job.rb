class DuelStreamJob < ApplicationJob
  queue_as :duels

  def perform(duel_ids, boards: true)
    Game::DuelsById.call(duel_ids).each do |duel|
      duel.seats.select(&:player_id).each do |seat|
        I18n.available_locales.each { broadcast(duel, seat, it, boards) }
      end
    end
  end

  private

  def broadcast(duel, seat, locale, boards)
    I18n.with_locale(locale) do
      screen = DuelScreen.new(duel, seat, locale:)
      streamables = DuelStream.streamables(seat.stream_key, locale)
      Turbo::StreamsChannel.broadcast_replace_to(*streamables, target: "duel-board", partial: "duels/board", locals: { screen: }) if boards
      Turbo::StreamsChannel.broadcast_update_to(*streamables, target: "duel-connection", partial: "duels/connection", locals: { screen: })
    end
  end
end

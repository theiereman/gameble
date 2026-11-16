class DuelStreamJob < ApplicationJob
  queue_as :duels

  def perform(duel_ids)
    Game::DuelsById.call(duel_ids).each do |duel|
      duel.seats.select(&:player_id).each do |seat|
        I18n.available_locales.each { broadcast(duel, seat, it) }
      end
    end
  end

  private

  def broadcast(duel, seat, locale)
    I18n.with_locale(locale) do
      Turbo::StreamsChannel.broadcast_replace_to(*DuelStream.streamables(seat.stream_key, locale), target: "duel-board",
        partial: "duels/board", locals: { screen: DuelScreen.new(duel, seat, locale:) })
    end
  end
end

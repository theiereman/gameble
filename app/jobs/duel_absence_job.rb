class DuelAbsenceJob < ApplicationJob
  queue_as :duels

  def perform
    duel_ids = Game::DuelsWithAbsentSeat.call(Time.current)
    DuelStreamJob.perform_later(duel_ids, boards: false) if duel_ids.any?
  end
end

class DuelPolicy < ApplicationPolicy
  def show? = player?
  def challenge? = player?

  def play? = seated?
  def accept? = seated?
  def announce? = seated?
  def answer? = seated?

  private
    def seated?
      player? && record.is_a?(Game::Duel) && record.seats.any? { it.player_id == player.id }
    end
end

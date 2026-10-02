# Opening packs and reading an opened pack (CAP-4, AD-14). A visitor sees the
# chest but is sent to sign in when acting on it (CAP-18).
#
#   authorize :pack, :create?
#   authorize pack, :show?
class PackPolicy < ApplicationPolicy
  # Any signed-in player; Game::OpenPack decides whether a pack is there.
  def create? = player?

  # The owner of an opened pack.
  def show?
    player? && record.is_a?(Game::Pack) && record.player_id == player.id && record.opened?
  end
end

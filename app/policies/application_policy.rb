# Base of every Pundit policy (AD-14). Denies by default: an action is allowed
# only where a policy says so. `player` is the signed-in player, or nil for a
# signed-out visitor; a banned player arrives here as a visitor.
class ApplicationPolicy
  attr_reader :player, :record

  def initialize(player, record)
    @player = player
    @record = record
  end

  def index? = false
  def show? = false
  def create? = false
  def new? = false
  def update? = false
  def edit? = false
  def destroy? = false

  # Role predicates, for the action predicates of subclasses.

  # A signed-out visitor: may look, may not act (CAP-18).
  def visitor?
    player.nil?
  end

  # Any signed-in player, whatever their role.
  def player?
    !player.nil?
  end

  # A moderator or an administrator.
  def moderator?
    player? && player.staff?
  end

  def administrator?
    player? && player.administrator?
  end
end

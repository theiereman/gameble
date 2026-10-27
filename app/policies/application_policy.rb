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


  def visitor?
    player.nil?
  end

  def player?
    !player.nil?
  end

  def moderator?
    player? && player.staff?
  end

  def administrator?
    player? && player.administrator?
  end
end

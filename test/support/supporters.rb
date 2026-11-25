# A player made a supporter the way the back office does it.
module Supporters
  def grant_supporter(player)
    Game::GrantSupporter.new.call(staff: accounts_players(:administrator), player:).value!
  end
end

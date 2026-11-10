module BalanceChipHelper
  def shell_balance
    return @shell_balance if defined?(@shell_balance)

    @shell_balance = (Game::Market::Balance.call(current_player) if current_player && Game::Market::MarketState.call.first_opened?)
  end
end

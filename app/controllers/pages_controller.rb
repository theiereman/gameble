class PagesController < ApplicationController
  def home
    authorize :page, :show?
    return unless current_player

    now = Time.current
    @bank = Game::BankSummary.call(current_player, now:)
    # Whole seconds to the next pack of the bank, rounded up so the countdown
    # reaches zero once the pack is due.
    @next_pack_in = (@bank[:next_available_at] - now).ceil if @bank[:next_available_at]
  end
end

class PagesController < ApplicationController
  def home
    authorize :page, :show?
    # A visitor sees the bonus panel whenever a player could collect one
    # (CAP-18): when a season is published.
    @season_published = Catalog::PublishedSeason.call.present? unless current_player
    return unless current_player

    now = Time.current
    @bank = Game::BankSummary.call(current_player, now:)
    # Whole seconds to the next pack of the bank, rounded up so the countdown
    # reaches zero once the pack is due.
    @next_pack_in = (@bank[:next_available_at] - now).ceil if @bank[:next_available_at]
  end
end

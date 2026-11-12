require "active_support/testing/time_helpers"

class EditionSalesSeed
  include ActiveSupport::Testing::TimeHelpers

  SALES = 5
  MARKUPS = [ 2, 3, 2, 4, 3 ].freeze

  def call
    players = (1..SALES + 1).map { player(it) }
    return puts("Edition sales already seeded.") if Game::Market::Listing.sold.where(seller_id: players.map(&:id)).count >= SALES

    edition = first_free_edition(players.first)
    return puts("No free copy to sell: skipped the edition sales.") unless edition

    sold = players.each_cons(2).with_index.count do |(seller, buyer), index|
      travel_to((SALES - index).days.ago) { sell(edition, seller, buyer, MARKUPS[index]) }
    end
    puts "Sold one edition #{sold} times."
  end

  private

  def player(number)
    Accounts::SignIn.new.call(steam_id: DevSignInsController.steam_id(number), persona_name: DevSignInsController.persona_name(number)).value!
  end

  def first_free_edition(player)
    free = Game::Holding.where(player_id: player.id).where("quantity > reserved").order(:card_season_id).pluck(:card_season_id)
    Catalog::CardSeason.where(id: free).where.not(rarity: nil).order(:id).pick(:id, :rarity)
  end

  def sell((card_season_id, rarity), seller, buyer, markup)
    settings = Game::Market::CurrentSettings.call
    minimum = settings.minimum_price(rarity.to_sym)
    listed = Game::Market::ListCard.new.call(player: seller, card_season_id:, starting_price: minimum, buy_now_price: minimum * markup,
      duration_hours: settings.duration_short_hours, settings_token: settings.token)
    return report(listed) unless listed.success?

    report(Game::Market::PlaceBid.new.call(player: buyer, listing_id: listed.value!.id, maximum: minimum * markup))
  end

  def report(result)
    puts "Edition sale skipped: #{result.failure}" if result.failure?
    result.success?
  end
end

EditionSalesSeed.new.call

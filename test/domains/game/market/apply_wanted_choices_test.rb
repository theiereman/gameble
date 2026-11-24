require "test_helper"
require_relative "../../../support/singleton_stub"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"
require_relative "../../../support/market_orders"

class Game::Market::ApplyWantedChoicesTest < ActiveSupport::TestCase
  include SingletonStub
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketOrders
  include MarketSettings

  Choices = Game::Market::ApplyWantedChoices

  setup do
    @seller = accounts_players(:player)
    @buyer = accounts_players(:moderator)
    @other = accounts_players(:administrator)
    @rare = catalog_card_seasons(:rare_card_one)
    @common = catalog_card_seasons(:common_card_one)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
    @epic = catalog_card_seasons(:portal_one)
    @settings = open_market!
    fund!(@buyer, 10_000)
    fund!(@other, 10_000)
    @order = order!(@buyer, @uncommon, 900)
  end

  def apply(lines, player: @seller, settings_token: Game::Market::CurrentSettings.call.token)
    Game::Market::ApplyWantedChoices.new.call(player:, lines:, settings_token:)
  end

  def sale(card, *orders, copies: orders.size) = { card_season_id: card.id, copies:, choice: "order", order_tokens: orders.map(&:token) }

  def auction(card, copies: 1, price: 100, hours: 24) = { card_season_id: card.id, copies:, choice: "auction", starting_price: price, duration_hours: hours }

  def entrust(card, copies: 1) = { card_season_id: card.id, copies:, choice: "entrust" }

  def copies(player, card) = Game::Holding.find_by(player_id: player.id, card_season_id: card.id)&.attributes&.values_at("quantity", "reserved")

  def deposited(card) = Game::Market::ArchiveDeposit.find_by(player_id: @seller.id, card_season_id: card.id)&.quantity

  def nothing_moves(&)
    assert_no_difference([ -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.sum(:quantity) }, -> { Game::Holding.sum(:reserved) },
      -> { Game::Market::Listing.count }, -> { Game::Market::ArchiveDeposit.sum(:quantity) }, -> { Game::Market::Order.where(status: "open").count },
      -> { Rails.configuration.event_store.read.count } ], &)
  end

  def refused(lines, **)
    result = nil
    nothing_moves { result = apply(lines, **) }
    result.failure
  end

  test "a sale, an auction and an entrustment apply together in one post that reconciles" do
    hold(@seller, @uncommon.id, 1)
    hold(@seller, @rare.id, 2)
    hold(@seller, @common.id, 2)
    fund!(@seller, 100)
    before = Game::Market::LedgerEntry.maximum(:id)

    result = apply([ sale(@uncommon, @order), auction(@rare, copies: 2, price: 100, hours: 72), entrust(@common, copies: 2) ])

    applied = result.value!
    listings = Game::Market::Listing.where(seller: @seller).order(:id)
    assert_equal [ Choices::Sold.new(line: 0, order: @order.reload, received: 810) ], applied.sold
    assert_equal listings.map { Choices::Listed.new(line: 1, listing: it) }, applied.listed
    assert_equal [ Choices::Entrusted.new(line: 2, copies: 2, minted: 20) ], applied.entrusted
    assert_empty applied.skipped
    assert_equal [ "served", @seller.id, @uncommon.id, 900 ], @order.attributes.values_at("status", "seller_id", "served_card_season_id", "average_after_sale")
    assert_equal [ [ 0, 0 ], [ 1, 0 ] ], [ copies(@seller, @uncommon), copies(@buyer, @uncommon) ]
    assert_equal [ 2, 2 ], copies(@seller, @rare)
    assert_equal [ [ "open", 100, 72, @rare.id ] ] * 2, listings.pluck(:status, :starting_price, :duration_hours, :card_season_id)
    assert_equal [ [ 0, 0 ], 2 ], [ copies(@seller, @common), deposited(@common) ]
    entries = Game::Market::LedgerEntry.where("id > ?", before)
    assert_equal [ [ @buyer.id, "purchase", 0, -900, @order.id, nil ], [ @seller.id, "sale", 900, 0, @order.id, nil ],
      [ @seller.id, "commission", -90, 0, @order.id, nil ], *listings.map { [ @seller.id, "stamp", -@settings.stamp(:rare), 0, nil, it.id ] }, [ @seller.id, "mint", 20, 0, nil, nil ] ],
      entries.order(:id).pluck(:player_id, :kind, :available_delta, :committed_delta, :order_id, :listing_id)
    assert_equal 1, entries.distinct.count(:created_at)
    assert_equal [ @settings.id ], entries.distinct.pluck(:settings_id)
    assert_equal [ 100 + 810 - 2 * @settings.stamp(:rare) + 20, 0 ], figures(@seller)
    assert Game::Market::ReconcileWallets.call.balanced?
    assert_equal [ { seller_id: @seller.id, sales: [ { order_id: @order.id, buyer_id: @buyer.id, card_season_id: @uncommon.id, price: 900 } ],
      listing_ids: listings.map(&:id), entrusted: [ { card_season_id: @common.id, quantity: 2 } ], converted: [] } ], events(Game::Market::WantedChoicesApplied).map(&:data)
    assert_equal 1, Rails.configuration.event_store.read.stream(Game::Operation.stream_name(@seller.id)).of_type(Game::Market::WantedChoicesApplied).count
    assert_empty [ Game::Market::CardListed, Game::Market::CardsEntrusted, Game::Market::OrderServed ].flat_map { events(it) }
  end

  test "the sale takes the order's version and the stamp, the commission and the mint the current one" do
    hold(@seller, @uncommon.id, 2)
    hold(@seller, @common.id, 1)
    current = open_market!(commission_basis_points: 2_000)
    before = Game::Market::LedgerEntry.maximum(:id)

    assert apply([ sale(@uncommon, @order), auction(@uncommon), entrust(@common) ]).success?

    assert_equal [ [ "commission", current.id ], [ "mint", current.id ], [ "purchase", @settings.id ], [ "sale", @settings.id ], [ "stamp", current.id ] ],
      Game::Market::LedgerEntry.where("id > ?", before).order(:kind).pluck(:kind, :settings_id)
  end

  test "an order line on a Rare and above is refused with its line and its code, and nothing moves" do
    hold(@seller, @epic.id, 1)
    hold(@seller, @uncommon.id, 1)
    drawn = order!(@other, @epic, 5_000)
    fund!(@other, 5_000)

    failure = refused([ sale(@uncommon, @order), sale(@epic, drawn) ])

    assert_equal [ :invalid_choices, [ Choices::Refused.new(line: 1, code: :direct_sale_not_for_rarity) ] ], failure
    assert_equal "open", drawn.reload.status
    assert_equal "Une Rare ou plus se vend aux enchères, que les ordres d'achat soutiennent.",
      I18n.with_locale(:fr) { Choices.failure_message(:direct_sale_not_for_rarity) }
  end

  test "an auction line at or below an order converts it inside the one transaction, with one event carrying it" do
    hold(@seller, @rare.id, 1)
    fund!(@seller, 100)
    leader = order!(@buyer, @rare, 900)

    applied = apply([ auction(@rare, price: 800) ]).value!

    listing = applied.listed.sole.listing.reload
    assert_equal [ @buyer.id, 900, 800, "bid" ], listing.attributes.values_at("leader_id", "leader_maximum", "current_price") + [ leader.reload.status ]
    assert_equal [ { order_id: leader.id, owner_id: @buyer.id, listing_id: listing.id, price: 900, status: "bid" } ], applied.converted
    assert_equal [ { order_id: leader.id, owner_id: @buyer.id, listing_id: listing.id, price: 900, status: "bid" } ],
      events(Game::Market::WantedChoicesApplied).sole.data[:converted]
    assert_equal [ [ @buyer.id, 900 ] ], entries_of(listing).where(kind: "hold").pluck(:player_id, :committed_delta)
    assert_equal [ [ @buyer.id, -900 ] ], Game::Market::LedgerEntry.where(order_id: leader.id, kind: "release").pluck(:player_id, :committed_delta)
    assert_equal [ 8_200, 1_800 ], figures(@buyer)
    assert_equal [ 1, 1 ], [ Game::Market::Bid.where(listing_id: listing.id).count, events(Game::Market::WantedChoicesApplied).size ]
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "an auction line above every order leaves them open and a Common order served in the same table is not converted" do
    hold(@seller, @rare.id, 1)
    hold(@seller, @uncommon.id, 1)
    fund!(@seller, 100)
    rare_order = order!(@other, @rare, 900)

    applied = apply([ auction(@rare, price: 950), sale(@uncommon, @order) ]).value!

    assert_equal [ "open", "served", [] ], [ rare_order.reload.status, @order.reload.status, applied.converted ]
    assert_nil applied.listed.sole.listing.leader_id
  end

  test "an order served by the table is not converted by an auction of another edition of its card" do
    season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    later = Catalog::CardSeason.find(Catalog::CardSeason.insert_all!([ { card_id: @uncommon.card_id, season_id: season.id, prestige_score: 0.7, rating: 80.0,
      rarity: @uncommon.rarity_before_type_cast, number: @uncommon.number } ], returning: :id).rows.flatten.sole)
    hold(@seller, @uncommon.id, 1)
    hold(@seller, later.id, 1)
    fund!(@seller, 100)

    applied = apply([ sale(@uncommon, @order), auction(later, price: 100) ]).value!

    assert_equal [ "served", [], nil ], [ @order.reload.status, applied.converted, applied.listed.sole.listing.reload.leader_id ]
    assert_empty Game::Market::LedgerEntry.where(order_id: @order.id, kind: "release")
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "a stamp is paid from the same validation's sale" do
    hold(@seller, @uncommon.id, 1)
    hold(@seller, @rare.id, 1)

    assert apply([ sale(@uncommon, @order), auction(@rare) ]).success?

    assert_equal [ 810 - @settings.stamp(:rare), 0 ], figures(@seller)
  end

  test "a stamp is paid from the same validation's entrustment within the cap" do
    hold(@seller, @rare.id, 1)
    hold(@seller, @common.id, 1)
    fund!(@seller, 15)

    assert apply([ auction(@rare), entrust(@common) ]).success?

    assert_equal [ 5, 0 ], figures(@seller)
  end

  test "auction lines whose stamps run past the funds are refused from the first one short" do
    hold(@seller, @rare.id, 2)
    hold(@seller, @common.id, 1)
    fund!(@seller, 30)

    failure = refused([ auction(@rare), auction(@rare), auction(@common, price: 13) ])

    short = 2 * @settings.stamp(:rare) + @settings.stamp(:common) - 30
    assert_equal [ :invalid_choices, [ Choices::Refused.new(line: 1, code: :stamp_not_covered, amount: short),
      Choices::Refused.new(line: 2, code: :stamp_not_covered, amount: short) ] ], failure
    assert_equal "Il vous manque #{short} PiCoins pour le timbre.",
      I18n.with_locale(:fr) { Choices.failure_message(:stamp_not_covered, amount: failure.last.first.amount) }
  end

  test "several copies on one order line serve the drawn orders best first and entrust the copy left without one" do
    better = order!(@other, @uncommon, 1_000)
    hold(@seller, @uncommon.id, 3)

    applied = apply([ sale(@uncommon, better, @order, copies: 3) ]).value!

    assert_equal [ better, @order ], applied.sold.map(&:order)
    assert_equal [ Choices::Entrusted.new(line: 0, copies: 1, minted: @settings.entrustment(:uncommon)) ], applied.entrusted
    assert_equal [ [ "served", 1_000 ], [ "served", 950 ] ], [ better, @order ].map { it.reload.attributes.values_at("status", "average_after_sale") }
    assert_equal [ [ 0, 0 ], [ 1, 0 ], [ 1, 0 ], 1 ], [ copies(@seller, @uncommon), copies(@buyer, @uncommon), copies(@other, @uncommon), deposited(@uncommon) ]
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "a copy the table drew no order for is entrusted though an order wants it" do
    hold(@seller, @uncommon.id, 1)

    assert apply([ entrust(@uncommon) ]).success?

    assert_equal [ "open", 1 ], [ @order.reload.status, deposited(@uncommon) ]
  end

  test "an order served, withdrawn or expired since the table was drawn refuses the table and names the line" do
    hold(@seller, @uncommon.id, 1)
    hold(@seller, @common.id, 1)
    lines = [ entrust(@common), sale(@uncommon, @order) ]

    [ { status: "withdrawn" }, { status: "served", seller_id: @other.id, served_card_season_id: @uncommon.id, served_at: Time.current, average_after_sale: 900 }, { expires_at: 1.minute.ago } ].each do |change|
      @order.update_columns(status: "open", expires_at: 7.days.from_now, seller_id: nil, served_card_season_id: nil, served_at: nil, average_after_sale: nil, **change)

      assert_equal [ :best_order_changed, [ Choices::Changed.new(line: 1, order: nil) ] ], refused(lines)
    end
  end

  test "a better order placed since the table was drawn refuses the table and names it" do
    hold(@seller, @uncommon.id, 1)
    better = order!(@other, @uncommon, 1_000)

    assert_equal [ :best_order_changed, [ Choices::Changed.new(line: 0, order: better) ] ], refused([ sale(@uncommon, @order) ])
  end

  test "an order that changes once the locks are held refuses the table" do
    hold(@seller, @uncommon.id, 1)
    locking = Game::TradeLocks.method(:players)
    placing = ->(*ids) { order!(@other, @uncommon, 1_000) && locking.call(*ids) }

    failure = stub_singleton(Game::TradeLocks, :players, placing) { apply([ sale(@uncommon, @order) ]) }.failure

    assert_equal [ :best_order_changed, 0, 1_000 ], [ failure.first, failure.last.sole.line, failure.last.sole.order.price ]
    assert_equal [ "open", [ 1, 0 ] ], [ @order.reload.status, copies(@seller, @uncommon) ]
  end

  test "an unknown or repeated token names the best order left after the earlier lines" do
    hold(@seller, @uncommon.id, 2)
    second = order!(@other, @uncommon, 800)

    assert_equal [ :best_order_changed, [ Choices::Changed.new(line: 0, order: @order) ] ], refused([ sale(@uncommon, Game::Market::Order.new(token: "unknown")) ])
    assert_equal [ :best_order_changed, [ Choices::Changed.new(line: 1, order: second) ] ], refused([ sale(@uncommon, @order), sale(@uncommon, @order) ])
  end

  test "a changed order is reported before the fields" do
    hold(@seller, @uncommon.id, 1)
    @order.update_columns(status: "withdrawn")

    assert_equal :best_order_changed, refused([ sale(@uncommon, @order), auction(@common, price: "x") ]).first
  end

  test "every invalid field is named with its line" do
    legendary = catalog_card_seasons(:legendary_card_one)
    legendary.update_columns(rarity: nil)
    hold(@seller, @rare.id, 2)
    hold(@seller, @common.id, 1)
    hold(@seller, @uncommon.id, 2, reserved: 1)
    hold(@seller, legendary.id, 1)
    fund!(@seller, 1_000)

    failure = refused([ auction(@rare, price: "abc"), auction(@rare, price: 50), auction(@common, hours: 5), entrust(@uncommon), auction(@uncommon),
      entrust(legendary) ])

    assert_equal [ :invalid_choices, [ [ 0, :invalid_price ], [ 1, :start_below_minimum, @settings.minimum_price(:rare) ], [ 2, :invalid_duration ],
      [ 3, :not_enough_copies ], [ 4, :not_enough_copies ], [ 5, :no_rarity ] ].map { |line, code, amount| Choices::Refused.new(line:, code:, amount:) } ], failure
    assert_equal "Au moins #{@settings.minimum_price(:rare)} pour une rare.",
      I18n.with_locale(:fr) { Choices.failure_message(:start_below_minimum, amount: failure.last[1].amount, rarity: "rare") }
  end

  test "a malformed line is refused before anything is read" do
    hold(@seller, @rare.id, 1)

    failure = refused([ { card_season_id: "x", copies: 1, choice: "entrust" }, entrust(@rare, copies: 0), { card_season_id: @rare.id, copies: 1, choice: "gift" },
      sale(@rare, @order, @order, copies: 1), entrust(@rare), "line" ])

    assert_equal [ :invalid_choices, [ 0, 1, 2, 3, 5 ].map { Choices::Refused.new(line: it, code: :invalid_choice) } ], failure
  end

  test "copies over the cap are skipped and kept while the rest applies" do
    open_market!(daily_cap: 60)
    hold(@seller, @rare.id, 2)
    hold(@seller, @common.id, 1)

    applied = apply([ entrust(@rare, copies: 2), entrust(@common) ]).value!

    assert_equal [ Choices::Entrusted.new(line: 0, copies: 1, minted: 50), Choices::Entrusted.new(line: 1, copies: 1, minted: 10) ], applied.entrusted
    assert_equal [ Choices::Skipped.new(line: 0, copies: 1) ], applied.skipped
    assert_equal [ [ 1, 0 ], 1, 1 ], [ copies(@seller, @rare), deposited(@rare), deposited(@common) ]
    assert_equal [ 60, 0 ], figures(@seller)
  end

  test "a table whose every copy is over the cap applies nothing" do
    open_market!(daily_cap: 100)
    fund!(@seller, 100)
    hold(@seller, @common.id, 1)

    assert_equal :nothing_fits, refused([ entrust(@common) ])
  end

  test "an already listed copy keeps its reservation beside the new auctions" do
    hold(@seller, @rare.id, 3)
    fund!(@seller, 100)
    listed = Game::Market::ListCard.new.call(player: @seller, card_season_id: @rare.id, starting_price: 100, duration_hours: 24, settings_token: @settings.token).value!

    assert apply([ auction(@rare), entrust(@rare) ]).success?

    assert_equal [ [ 2, 2 ], "open" ], [ copies(@seller, @rare), listed.reload.status ]
  end

  test "an empty table, a closed market, a stale version, a removed seller and a deadlock are refused" do
    hold(@seller, @common.id, 1)

    assert_equal :empty_batch, refused([])
    assert_equal :amounts_changed, refused([ entrust(@common) ], settings_token: "stale")
    stub_singleton(Game::Market::Ledger, :post, ->(*) { raise ActiveRecord::Deadlocked }) do
      assert_equal :market_busy, refused([ entrust(@common) ])
    end
    close_market!
    assert_equal :market_closed, refused([ entrust(@common) ])
    @seller.update_columns(banned_at: Time.current)
    assert_equal :player_required, refused([ entrust(@common) ])
  end
end

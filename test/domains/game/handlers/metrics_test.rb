require "test_helper"
require_relative "../../../support/singleton_stub"

class Game::Handlers::MetricsTest < ActiveSupport::TestCase
  include SingletonStub

  test "a served order counts once and records its price, naming no player" do
    counted = capture_metrics { publish(Game::Market::OrderServed.new(data: { order_id: 1, buyer_id: 2, seller_id: 3, card_season_id: 4, price: 120 })) }

    assert_equal [ [ :count, "market.order.served", nil ], [ :distribution, "market.order.served.price", 120 ] ], counted
  end

  test "a slot purchase counts with its kind and nothing else" do
    counted = capture_metrics { publish(Game::SlotBought.with(player_id: 1, kind: "deck")) }

    assert_equal [ [ :count, "slot.bought", { kind: "deck" } ] ], counted
  end

  test "every counted event is heard once the transaction commits" do
    counted = capture_metrics do
      ActiveRecord::Base.transaction do
        publish(Game::PackOpened.new(data: { pack_id: 0, player_id: 0 }))
        assert_empty @seen
      end
    end

    assert_equal [ [ :count, "pack.opened", nil ] ], counted
  end

  test "a failing metric is reported and never breaks the event" do
    reported = []
    original = Rails.error.method(:report)
    Rails.error.define_singleton_method(:report) { |error, **| reported << error.message }
    stub_singleton(Sentry::Metrics, :count, ->(*, **) { raise "sentry down" }) { publish(Game::DuelFinished.new) }

    assert_equal [ "sentry down" ], reported
  ensure
    Rails.error.define_singleton_method(:report, original)
  end

  private
    def publish(event) = Game::Handlers::Metrics.call(event)

    def capture_metrics
      @seen = []
      stub_singleton(Sentry::Metrics, :count, ->(name, attributes: nil, **) { @seen << [ :count, name, attributes ] }) do
        stub_singleton(Sentry::Metrics, :distribution, ->(name, value, **) { @seen << [ :distribution, name, value ] }) { yield }
      end
      @seen
    end
end

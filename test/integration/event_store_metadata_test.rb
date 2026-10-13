require "test_helper"
require_relative "../support/steam_api_stubs"
require_relative "../support/steam_sign_in"
require Rails.root.join("db/migrate/20261009150000_strip_remote_ip_from_event_store_metadata").to_s

# The event store keeps no IP address: events published during a request
# carry its request id only, and the migration strips the address from the
# events stored before.
class EventStoreMetadataTest < ActionDispatch::IntegrationTest
  include SteamApiStubs
  include SteamSignIn

  IP = "203.0.113.7".freeze
  STEAM_ID = "76561197960287930".freeze

  setup do
    mock_steam_sign_in(STEAM_ID)
    stub_steam_api
  end

  teardown do
    unstub_steam_api
  end

  def event_store = Rails.configuration.event_store

  def stored_row(event)
    row = ActiveRecord::Base.connection.select_one(
      ActiveRecord::Base.sanitize_sql_array([ "SELECT * FROM event_store_events WHERE event_id = ?", event.event_id ])
    )
    row.merge("metadata" => JSON.parse(row.fetch("metadata")), "data" => JSON.parse(row.fetch("data")))
  end

  def publish_with_metadata(metadata)
    event = Accounts::RoleChanged.new(data: { player_id: accounts_players(:player).id, role: "moderator" })
    event_store.with_metadata(metadata) { event_store.publish(event, stream_name: "Accounts::Player$#{accounts_players(:player).id}") }
    event
  end

  def migrate
    ActiveRecord::Migration.suppress_messages { StripRemoteIpFromEventStoreMetadata.new.migrate(:up) }
  end

  test "an event published during a request carries the request id and no IP address" do
    post "/auth/steam", params: { origin: "/en" }, env: { "REMOTE_ADDR" => IP }
    get "/auth/steam/callback", env: { "REMOTE_ADDR" => IP }

    registered = event_store.read.of_type(Accounts::PlayerRegistered).last
    assert_equal response.headers["X-Request-Id"], registered.metadata[:request_id]
    assert_not registered.metadata.to_h.key?(:remote_ip)
    stored_metadata = stored_row(registered).fetch("metadata").to_json
    assert_not_includes stored_metadata, "remote_ip"
    assert_not_includes stored_metadata, IP
  end

  test "the migration strips the IP address from a stored event and leaves the rest of the event as it was" do
    event = publish_with_metadata(remote_ip: IP, request_id: "a-request")
    before = stored_row(event)
    assert_equal IP, before.dig("metadata", "remote_ip")

    migrate

    after = stored_row(event)
    expected_metadata = before["metadata"].except("remote_ip")
    expected_metadata["types"] = { **before["metadata"]["types"], "metadata" => before.dig("metadata", "types", "metadata").except("remote_ip") }
    assert_equal before.merge("metadata" => expected_metadata), after
    assert_equal "a-request", after.dig("metadata", "request_id")

    read_back = event_store.read.event(event.event_id)
    assert_equal event.data, read_back.data
    assert_equal "a-request", read_back.metadata[:request_id]
    assert_not read_back.metadata.to_h.key?(:remote_ip)
  end

  test "the migration leaves a stored event without an IP address unchanged" do
    event = publish_with_metadata(request_id: "a-request")
    before = stored_row(event)

    migrate

    assert_equal before, stored_row(event)
  end
end

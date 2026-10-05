require "test_helper"

# A test-only controller probing the database role a request runs on (AD-11).
# It takes no policy decision: it exists to write where no page should.
class ReadOnlyProbeController < ApplicationController
  skip_after_action :verify_authorized

  class ProbeJob < ActiveJob::Base
    def perform = nil
  end

  # The role and write guard the action ran under.
  def role
    render plain: "#{ApplicationRecord.current_role} #{ApplicationRecord.current_preventing_writes}"
  end

  # Writes an ApplicationRecord row.
  def write
    Accounts::Player.create!(steam_id: "76561197960287777")
    render plain: "written"
  end

  # Writes an event (Rails Event Store's own models, on ActiveRecord::Base).
  def publish
    Rails.configuration.event_store.publish(Accounts::PlayerRegistered.new(data: { player_id: 0 }), stream_name: "probe")
    render plain: "published"
  end

  # Enqueues a job, which is not a write to the primary.
  def enqueue
    ProbeJob.perform_later
    render plain: "enqueued"
  end
end

# GET and HEAD requests run under the reading role with writes prevented
# (AD-11); other verbs write; the Steam callback is the one GET exempt.
class ReadOnlyRequestsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def with_probe_routes
    with_routing do |set|
      set.draw do
        scope ":locale", locale: /en|fr/ do
          root "pages#home", as: :home
        end
        match "probe/role" => "read_only_probe#role", via: %i[get post]
        match "probe/write" => "read_only_probe#write", via: %i[get head post]
        get "probe/publish" => "read_only_probe#publish"
        get "probe/enqueue" => "read_only_probe#enqueue"
      end
      yield
    end
  end

  test "a GET runs on the reading role with writes prevented; a POST on the writing role" do
    with_probe_routes do
      get "/probe/role"
      assert_equal "reading true", response.body

      post "/probe/role"
      assert_equal "writing false", response.body
    end
  end

  test "a GET or HEAD that writes a row raises ReadOnlyError and writes nothing; a POST writes" do
    with_probe_routes do
      assert_no_difference -> { Accounts::Player.count } do
        assert_raises(ActiveRecord::ReadOnlyError) { get "/probe/write" }
        assert_raises(ActiveRecord::ReadOnlyError) { head "/probe/write" }
      end

      assert_difference -> { Accounts::Player.count }, 1 do
        post "/probe/write"
      end
      assert_equal "written", response.body
    end
  end

  test "a GET that publishes an event raises ReadOnlyError" do
    with_probe_routes do
      assert_raises(ActiveRecord::ReadOnlyError) { get "/probe/publish" }
    end

    assert_empty Rails.configuration.event_store.read.stream("probe").to_a
  end

  test "a GET may enqueue a job" do
    with_probe_routes do
      assert_enqueued_with(job: ReadOnlyProbeController::ProbeJob) { get "/probe/enqueue" }
      assert_equal "enqueued", response.body
    end
  end

  test "outside a request, the writing role is back" do
    with_probe_routes { get "/probe/role" }

    assert_equal :writing, ApplicationRecord.current_role
    assert_not ApplicationRecord.current_preventing_writes
  end
end

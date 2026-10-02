# One Rails Event Store client for the whole app (AD-10). Operations publish
# through ApplicationOperation#publish, inside their own transaction.
Rails.configuration.to_prepare do
  Rails.configuration.event_store = RailsEventStore::JSONClient.new
end

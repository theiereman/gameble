module Game
  module Handlers
    # The players an event names, from a map of event class to its data keys or to a callable over its data.
    module NamedPlayers
      def self.of(event, map)
        named = map.fetch(event.class)
        ids = named.respond_to?(:call) ? named.call(event.data) : named.map { event.data.fetch(it) }
        ids.compact.uniq
      end
    end
  end
end

# The test cache store (:null_store) counts nothing, so Rails' `rate_limit`
# never throttles in tests. `rate_limit` captures the controller's cache
# store when the class loads, so swapping the store afterwards changes
# nothing: this helper makes that captured store count in memory for the
# duration of the block, then restores it.
#
#   with_counting_rate_limit(PacksController) { 31.times { post packs_path } }
module CountingRateLimit
  def with_counting_rate_limit(controller)
    memory = ActiveSupport::Cache::MemoryStore.new
    store = controller.cache_store
    store.define_singleton_method(:increment) { |*args, **options| memory.increment(*args, **options) }
    yield
  ensure
    store.singleton_class.remove_method(:increment) if store&.singleton_class&.method_defined?(:increment, false)
  end
end

# Replaces a module method for the length of a block, then puts the original back.
#
#   stub_singleton(PushNotices, :deliverable?, ->(_device) { true }) { PushNoticeJob.perform_now(notices) }
module SingletonStub
  def stub_singleton(object, name, replacement)
    original = object.method(name)
    object.define_singleton_method(name, &replacement)
    yield
  ensure
    object.define_singleton_method(name, original)
  end
end

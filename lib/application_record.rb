# Base class of every Active Record model. It lives in the `lib` package so
# pack models can inherit it without depending on the web layer.
#
# The `reading` role is declared from the start and points to the
# primary. GET and HEAD requests run under it with writes prevented
# (ApplicationController). Adding a read replica takes more than
# `reading: :primary_replica`: pages read right after a write (the hub
# after POST /daily-bonus, the pack page after POST /packs) must then stay
# on the primary, for instance for a short window after a write, or a
# lagging replica serves them stale data. The
# role is switched on this class only, never on ActiveRecord::Base: Solid
# Queue and Solid Cache keep their own connection classes and stay writable.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  connects_to database: { writing: :primary, reading: :primary }
end

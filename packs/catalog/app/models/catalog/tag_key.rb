module Catalog
  # The identity of a Steam tag in Catalog: its English name parameterized
  # with `_` (parameterize keeps hyphens, so they become `_` too: "Co-op" and
  # "Co op" are both "co_op"). Blank when the name leaves nothing.
  #
  #   Catalog::TagKey.of("Souls-like") # => "souls_like"
  module TagKey
    FORMAT = /\A[a-z0-9_]+\z/

    def self.of(name)
      name.to_s.parameterize(separator: "_", locale: :en).tr("-", "_").squeeze("_").delete_prefix("_").delete_suffix("_")
    end
  end
end

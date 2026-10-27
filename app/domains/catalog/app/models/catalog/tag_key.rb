module Catalog
  module TagKey
    FORMAT = /\A[a-z0-9_]+\z/

    def self.of(name)
      name.to_s.parameterize(separator: "_", locale: :en).tr("-", "_").squeeze("_").delete_prefix("_").delete_suffix("_")
    end
  end
end

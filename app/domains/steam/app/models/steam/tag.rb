module Steam
  # A Steam store tag named in English (epic 2 R4), from GetTagList. Upserted
  # on tagid by Steam::ImportTagsPage. A game's tags are the tagids of
  # Steam::App#tag_ids, named here.
  class Tag < ApplicationRecord
    self.table_name = "steam_tags"
  end
end

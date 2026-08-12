module Plum
  class EntryTerm < ApplicationRecord
    include StaticCacheInvalidation
    belongs_to :entry
    belongs_to :term

    validates :term_id, uniqueness: { scope: :entry_id }
  end
end

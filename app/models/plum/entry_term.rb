module Plum
  class EntryTerm < ApplicationRecord
    belongs_to :entry
    belongs_to :term

    validates :term_id, uniqueness: { scope: :entry_id }
  end
end

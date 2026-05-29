module Plum
  class FormSubmission < ApplicationRecord
    include SiteScoped

    belongs_to :form_definition

    validates :data, presence: true

    def value(key)
      data&.dig(key)
    end
  end
end

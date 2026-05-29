class FormSubmission < ApplicationRecord
  belongs_to :form_definition

  validates :data, presence: true

  def value(key)
    data&.dig(key)
  end
end

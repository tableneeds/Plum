class Asset < ApplicationRecord
  has_one_attached :file

  validates :file, presence: true

  def filename
    file.filename.to_s
  end

  def content_type
    file.content_type
  end

  def url
    Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true)
  end
end

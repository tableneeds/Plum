module Plum
  class Asset < ApplicationRecord
    include SiteScoped

    has_one_attached :file

    validates :file, presence: true
    validate :file_must_be_image

    before_validation :normalize_folder

    def filename
      file.attached? ? file.filename.to_s : ""
    end

    def content_type
      file.content_type if file.attached?
    end

    def image?
      content_type.to_s.start_with?("image/")
    end

    def url
      return "" unless file.attached?

      Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true)
    end

    def to_liquid
      {
        "id" => id,
        "url" => url,
        "alt_text" => alt_text.to_s,
        "caption" => caption.to_s,
        "filename" => filename,
        "content_type" => content_type.to_s,
        "byte_size" => file.attached? ? file.byte_size : nil,
        "folder" => folder.to_s
      }
    end

    private

    def normalize_folder
      self.folder = folder.to_s.strip.presence
    end

    def file_must_be_image
      return unless file.attached?
      return if image?

      errors.add(:file, "must be an image")
    end
  end
end

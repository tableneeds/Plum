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

    def variant_url(transformations)
      return url unless file.attached? && file.variable?

      variant = file.variant(transformations)
      Rails.application.routes.url_helpers.rails_blob_path(variant.processed, only_path: true)
    rescue StandardError, LoadError
      url
    end

    def to_liquid
      {
        "id" => id,
        "url" => url,
        "thumb" => variant_url(resize_to_fill: [ 300, 300 ]),
        "small" => variant_url(resize_to_limit: [ 640, 640 ]),
        "medium" => variant_url(resize_to_limit: [ 1200, 1200 ]),
        "large" => variant_url(resize_to_limit: [ 2000, 2000 ]),
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

module Plum
  module Cp
    module AssetsHelper
      def plum_asset_label(asset)
        [ asset.filename, asset.alt_text.presence ].compact.join(" - ")
      end

      def plum_asset_image_url(asset)
        return unless asset&.file&.attached?

        asset.url
      end

      def plum_asset_file_size(asset)
        return "0 B" unless asset.file.attached?

        number_to_human_size(asset.file.byte_size)
      end
    end
  end
end

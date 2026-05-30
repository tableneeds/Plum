require "rack/mime"

module Plum
  class ThemeAssetsController < ApplicationController
    def show
      asset_path = ThemeResolver.new.find_asset(params[:theme_handle], params[:path])
      return head :not_found unless asset_path

      send_file asset_path,
        type: Rack::Mime.mime_type(asset_path.extname, "application/octet-stream"),
        disposition: "inline"
    end
  end
end

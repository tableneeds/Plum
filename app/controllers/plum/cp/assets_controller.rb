module Plum
  module Cp
    class AssetsController < BaseController
      before_action :set_asset, only: [ :edit, :update, :destroy ]

      def index
        @assets = asset_scope.order(created_at: :desc)
        @asset = asset_scope.build
      end

      def new
        @asset = asset_scope.build
      end

      def create
        @asset = asset_scope.build(asset_params)

        if @asset.save
          redirect_to cp_assets_path, notice: "Asset uploaded"
        else
          @assets = asset_scope.order(created_at: :desc)
          render :index, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @asset.update(asset_params)
          redirect_to cp_assets_path, notice: "Asset updated"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @asset.destroy
        redirect_to cp_assets_path, notice: "Asset deleted"
      end

      private

      def asset_scope
        current_site.assets.with_attached_file
      end

      def set_asset
        @asset = asset_scope.find(params[:id])
      end

      def asset_params
        params.require(:asset).permit(:file, :alt_text, :caption, :folder)
      end
    end
  end
end

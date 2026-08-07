module Plum
  module Cp
    class AssetsController < BaseController
      include Plum::Cp::AssetsHelper

      before_action :set_asset, only: [ :edit, :update, :destroy ]
      before_action :require_editor, only: [ :new, :create, :edit, :update, :destroy ]

      def index
        @assets = asset_scope.order(created_at: :desc)
        @asset = asset_scope.build

        respond_to do |format|
          format.html
          format.json { render json: @assets.map { |asset| asset_json(asset) } }
        end
      end

      def new
        @asset = asset_scope.build
      end

      def create
        @asset = asset_scope.build(asset_params)

        if @asset.save
          respond_to do |format|
            format.html { redirect_to cp_assets_path, notice: "Asset uploaded" }
            format.json { render json: asset_json(@asset), status: :created }
          end
        else
          respond_to do |format|
            format.html do
              @assets = asset_scope.order(created_at: :desc)
              render :index, status: :unprocessable_entity
            end
            format.json { render json: { errors: @asset.errors.full_messages }, status: :unprocessable_entity }
          end
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
        params.require(:asset).permit(:file, :alt_text, :caption, :folder, :focal_x, :focal_y)
      end

      def asset_json(asset)
        {
          id: asset.id,
          url: asset.url,
          filename: asset.filename,
          folder: asset.folder.to_s,
          alt_text: asset.alt_text.to_s,
          focal_x: asset.focal_x,
          focal_y: asset.focal_y,
          object_position: "#{asset.focal_x}% #{asset.focal_y}%",
          label: plum_asset_label(asset)
        }
      end
    end
  end
end

module Plum
  module Cp
    class GlobalsController < BaseController
      helper_method :global_data_json

      before_action :set_global, only: [ :show, :edit, :update, :destroy ]
      before_action :require_editor, only: [ :new, :create, :edit, :update, :destroy ]

      def index
        @globals = current_site.globals.order(:name)
      end

      def show
      end

      def new
        @global = current_site.globals.build(data: {})
      end

      def create
        @global = current_site.globals.build(global_params)

        if assign_data(@global) && @global.save
          redirect_to cp_global_path(@global), notice: "Global created"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        @global.assign_attributes(global_params)

        if assign_data(@global) && @global.save
          redirect_to cp_global_path(@global), notice: "Global updated"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @global.destroy
        redirect_to cp_globals_path, notice: "Global deleted"
      end

      private

      def set_global
        @global = current_site.globals.find(params[:id])
      end

      def global_params
        params.require(:global).permit(:name, :handle)
      end

      def assign_data(global)
        @data_json = params.dig(:global, :data_json)
        global.data = parse_data_json(@data_json)
        true
      rescue JSON::ParserError
        global.errors.add(:data, "must be valid JSON")
        false
      rescue TypeError
        global.errors.add(:data, "must be a JSON object")
        false
      end

      def parse_data_json(raw_json)
        data = JSON.parse(raw_json.presence || "{}")
        raise TypeError unless data.is_a?(Hash)

        data
      end

      def global_data_json(global)
        return @data_json if defined?(@data_json) && @data_json.present?

        JSON.pretty_generate(global.data)
      end
    end
  end
end

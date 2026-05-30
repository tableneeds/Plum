module Plum
  module Cp
    class FormDefinitionsController < BaseController
      helper_method :form_fields_json

      before_action :set_form_definition, only: [ :show, :edit, :update, :destroy ]

      def index
        @form_definitions = current_site.form_definitions.includes(:form_submissions).order(:name)
      end

      def show
        @submissions = @form_definition.form_submissions.order(created_at: :desc)
      end

      def new
        @form_definition = current_site.form_definitions.build(fields: [])
      end

      def create
        @form_definition = current_site.form_definitions.build(form_definition_params)

        if assign_fields(@form_definition) && @form_definition.save
          redirect_to cp_form_definition_path(@form_definition), notice: "Form created"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        @form_definition.assign_attributes(form_definition_params)

        if assign_fields(@form_definition) && @form_definition.save
          redirect_to cp_form_definition_path(@form_definition), notice: "Form updated"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @form_definition.destroy
        redirect_to cp_form_definitions_path, notice: "Form deleted"
      end

      private

      def set_form_definition
        @form_definition = current_site.form_definitions.find(params[:id])
      end

      def form_definition_params
        params.require(:form_definition).permit(:name, :handle, :notification_email)
      end

      def assign_fields(form_definition)
        @fields_json = params.dig(:form_definition, :fields_json)
        form_definition.fields = normalized_fields(@fields_json)
        true
      rescue JSON::ParserError
        form_definition.errors.add(:fields, "must be valid JSON")
        false
      end

      def normalized_fields(raw_json)
        parsed = JSON.parse(raw_json.presence || '{"fields":[]}')
        fields = parsed.is_a?(Hash) ? parsed["fields"] : parsed
        Array(fields).filter_map { |field| normalized_field(field) }
      end

      def normalized_field(field)
        return unless field.is_a?(Hash)

        handle = field["handle"].to_s.strip
        return if handle.blank?

        {
          "handle" => handle,
          "type" => normalized_field_type(field["type"]),
          "label" => field["label"].to_s.strip.presence || handle.humanize,
          "required" => ActiveModel::Type::Boolean.new.cast(field["required"]),
          "options" => normalized_options(field["options"])
        }
      end

      def normalized_field_type(type)
        type = type.to_s
        FormDefinition::FIELD_TYPES.include?(type) ? type : "text"
      end

      def normalized_options(options)
        Array(options).flat_map { |value| value.to_s.split(",") }.map(&:strip).reject(&:blank?)
      end

      def form_fields_json(form_definition)
        return @fields_json if defined?(@fields_json) && @fields_json.present?

        JSON.pretty_generate({ fields: form_definition.form_fields })
      end
    end
  end
end

module Plum
  module Cp
    class TaxonomiesController < BaseController
      before_action :set_taxonomy, only: [ :show, :edit, :update, :destroy ]
      before_action :require_admin, only: [ :new, :create, :edit, :update, :destroy ]

      def index
        @taxonomies = current_site.taxonomies.order(:name)
      end

      def show
        @terms = @taxonomy.terms.ordered
      end

      def new
        @taxonomy = current_site.taxonomies.build
      end

      def create
        @taxonomy = current_site.taxonomies.build(taxonomy_params)

        if @taxonomy.save
          redirect_to "/cp/taxonomies/#{@taxonomy.id}", notice: "Taxonomy created"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @taxonomy.update(taxonomy_params)
          redirect_to "/cp/taxonomies/#{@taxonomy.id}", notice: "Taxonomy updated"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @taxonomy.destroy
        redirect_to "/cp/taxonomies", notice: "Taxonomy deleted"
      end

      private

      def set_taxonomy
        @taxonomy = current_site.taxonomies.find(params[:id])
      end

      def taxonomy_params
        params.require(:taxonomy).permit(:name, :handle, :slug)
      end
    end
  end
end

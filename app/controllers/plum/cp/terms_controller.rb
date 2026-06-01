module Plum
  module Cp
    class TermsController < BaseController
      before_action :set_taxonomy
      before_action :set_term, only: [ :edit, :update, :destroy ]
      before_action :require_admin, only: [ :new, :create, :edit, :update, :destroy ]

      def new
        @term = @taxonomy.terms.build(site: current_site)
      end

      def create
        @term = @taxonomy.terms.build(term_params)
        @term.site = current_site
        @term.position = @taxonomy.terms.maximum(:position).to_i + 1

        if @term.save
          redirect_to "/cp/taxonomies/#{@taxonomy.id}", notice: "Term created"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @term.update(term_params)
          redirect_to "/cp/taxonomies/#{@taxonomy.id}", notice: "Term updated"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @term.destroy
        redirect_to "/cp/taxonomies/#{@taxonomy.id}", notice: "Term deleted"
      end

      private

      def set_taxonomy
        @taxonomy = current_site.taxonomies.find(params[:taxonomy_id])
      end

      def set_term
        @term = @taxonomy.terms.find(params[:id])
      end

      def term_params
        params.require(:term).permit(:name, :slug)
      end
    end
  end
end

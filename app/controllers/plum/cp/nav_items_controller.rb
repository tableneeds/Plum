module Plum
  module Cp
    class NavItemsController < BaseController
      before_action :set_nav_menu
      before_action :set_nav_item, only: [ :edit, :update, :destroy ]
      before_action :set_form_options, only: [ :new, :create, :edit, :update ]
      before_action :require_editor, only: [ :new, :create, :edit, :update, :destroy ]

      def new
        @nav_item = @nav_menu.nav_items.build(site: current_site, position: next_position)
      end

      def create
        @nav_item = @nav_menu.nav_items.build(nav_item_params)
        @nav_item.site = current_site

        if @nav_item.save
          redirect_to cp_nav_menu_path(@nav_menu), notice: "Navigation item created"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @nav_item.update(nav_item_params)
          redirect_to cp_nav_menu_path(@nav_menu), notice: "Navigation item updated"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @nav_item.destroy
        redirect_to cp_nav_menu_path(@nav_menu), notice: "Navigation item deleted"
      end

      private

      def set_nav_menu
        @nav_menu = current_site.nav_menus.find(params[:nav_menu_id])
      end

      def set_nav_item
        @nav_item = @nav_menu.nav_items.find(params[:id])
      end

      def set_form_options
        @entries = current_site.entries.includes(:content_type).order(:title)
        @parent_options = @nav_menu.nav_items.where.not(id: @nav_item&.id).includes(:entry).order(:position, :label)
      end

      def next_position
        @nav_menu.nav_items.maximum(:position).to_i + 1
      end

      def nav_item_params
        permitted = params.require(:nav_item).permit(:label, :url, :entry_id, :parent_id, :position)
        permitted[:entry_id] = nil if permitted[:entry_id].blank?
        permitted[:parent_id] = nil if permitted[:parent_id].blank?
        permitted[:position] = next_position if permitted[:position].blank?
        permitted
      end
    end
  end
end

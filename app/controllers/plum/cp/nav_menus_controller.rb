module Plum
  module Cp
    class NavMenusController < BaseController
      before_action :set_nav_menu, only: [ :show, :edit, :update, :destroy ]
      before_action :require_editor, only: [ :new, :create, :edit, :update, :destroy ]

      def index
        @nav_menus = current_site.nav_menus.includes(:nav_items).order(:name)
      end

      def show
        @nav_items = @nav_menu.root_items.includes(:entry, children: :entry)
      end

      def new
        @nav_menu = current_site.nav_menus.build
      end

      def create
        @nav_menu = current_site.nav_menus.build(nav_menu_params)

        if @nav_menu.save
          redirect_to cp_nav_menu_path(@nav_menu), notice: "Navigation menu created"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @nav_menu.update(nav_menu_params)
          redirect_to cp_nav_menu_path(@nav_menu), notice: "Navigation menu updated"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @nav_menu.destroy
        redirect_to cp_nav_menus_path, notice: "Navigation menu deleted"
      end

      private

      def set_nav_menu
        @nav_menu = current_site.nav_menus.find(params[:id])
      end

      def nav_menu_params
        params.require(:nav_menu).permit(:name, :handle)
      end
    end
  end
end

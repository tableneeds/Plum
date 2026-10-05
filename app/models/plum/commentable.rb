module Plum
  module Commentable
    extend ActiveSupport::Concern

    included do
      has_one :plum_discussion, as: :commentable, class_name: "Plum::Discussion", dependent: :destroy
    end

    def plum_comment_site
      site if respond_to?(:site)
    end

    def plum_comments_enabled?
      true
    end

    def plum_comments_open?
      plum_comments_enabled?
    end

    def plum_discussion_title
      respond_to?(:title) ? title : self.class.model_name.human
    end
  end
end

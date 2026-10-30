module Plum
  module CommentsHelper
    # Safe for dynamic Rails views. Do not put personalized forms in a static cache.
    def plum_discussion_path(subject, handle: "entries")
      if respond_to?(:plum)
        plum.discussion_path(handle: handle, subject_id: subject.id)
      else
        discussion_path(handle: handle, subject_id: subject.id)
      end
    end

    def plum_comments_link(subject, handle: "entries", label: "Questions & discussion")
      return unless Plum.configuration.comments.enabled
      context = Comments::Context.new(controller, handle: handle, id: subject.id)
      link_to label, plum_discussion_path(context.subject, handle: handle), class: "plum-comments-link"
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end
end

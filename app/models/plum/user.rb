module Plum
  class User < ApplicationRecord
    has_secure_password

    has_many :entries, foreign_key: :author_id, dependent: :nullify
    has_many :entry_revisions, foreign_key: :editor_id, dependent: :nullify

    enum :role, { viewer: 0, editor: 1, admin: 2 }

    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :role, presence: true

    def admin?
      role == "admin"
    end
  end
end

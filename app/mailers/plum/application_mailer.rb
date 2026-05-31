module Plum
  class ApplicationMailer < ActionMailer::Base
    default from: -> { Plum.configuration.mailer_sender }
    layout "mailer"
  end
end

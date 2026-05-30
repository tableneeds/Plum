ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "base64"
require "rails/test_help"
require "stringio"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    TEST_PNG_DATA = Base64.decode64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
    )

    def attach_test_png(record, filename: "test.png")
      record.file.attach(
        io: StringIO.new(TEST_PNG_DATA),
        filename: filename,
        content_type: "image/png"
      )
    end

    def png_fixture_path(filename: "test.png")
      path = Rails.root.join("tmp", "#{SecureRandom.hex(8)}-#{filename}")
      File.binwrite(path, TEST_PNG_DATA)
      path
    end
  end
end

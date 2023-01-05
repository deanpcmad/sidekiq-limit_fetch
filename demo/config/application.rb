# frozen_string_literal: true

require File.expand_path('boot', __dir__)

require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'sprockets/railtie'

Bundler.require(:default, Rails.env)

module Demo
  Application = Class.new Rails::Application
end

# frozen_string_literal: true

require "rspec/sunspot/profiles"

RSpec::Sunspot::Profiles.configure do |config|
  config.profiles_path = Rails.root.join("spec/data_profiles").to_s
end

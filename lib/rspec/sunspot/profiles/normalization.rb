# frozen_string_literal: true

require "time"

module RSpec
  module Sunspot
    module Profiles
      module Normalization
        class << self
          def normalize_payload(value)
            normalize(value)
          end

          private

          def normalize(value)
            case value
            when Hash
              value.each_with_object({}) do |(key, nested_value), normalized|
                normalized[key.to_s] = normalize(nested_value)
              end.sort.to_h
            when Array
              value.map { |element| normalize(element) }
            when Time
              value.utc.iso8601(6)
            when Symbol
              value.to_s
            else
              value
            end
          end
        end
      end
    end
  end
end

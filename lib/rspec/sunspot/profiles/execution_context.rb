# frozen_string_literal: true

module RSpec
  module Sunspot
    module Profiles
      class ExecutionContext
        def initialize
          @data = {}
          @records = []
        end

        def evaluate(&)
          merge_payload(instance_exec(&))
          @data["records"] = deep_merge(@data.fetch("records", []), @records) unless @records.empty?
          @data
        end

        def factory_bot(name, *traits, **attributes, &)
          raise Error, "FactoryBot is not defined" unless defined?(::FactoryBot)

          record = ::FactoryBot.create(name, *traits, **attributes, &)
          @records << serialize_record(record)
          record
        end
        # rubocop:disable Naming/MethodName
        alias FactoryBot factory_bot
        # rubocop:enable Naming/MethodName

        def data(payload = nil, **entries)
          payload = entries if payload.nil? && !entries.empty?
          merge_payload(payload)
        end

        private

        def merge_payload(payload)
          return @data if payload.nil?
          return @data unless payload.is_a?(Hash)

          @data = deep_merge(@data, Fingerprint.normalize_payload(payload))
          @data
        end

        def deep_merge(left, right)
          if left.is_a?(Hash) && right.is_a?(Hash)
            left.merge(right) do |_key, left_value, right_value|
              deep_merge(left_value, right_value)
            end
          elsif left.is_a?(Array) && right.is_a?(Array)
            left + right
          else
            right
          end
        end

        def serialize_record(record)
          return record if serializable_value?(record)

          if record.respond_to?(:id)
            {
              "class" => record.class.name,
              "id" => record.id
            }
          else
            record.inspect
          end
        end

        def serializable_value?(value)
          case value
          when NilClass, Numeric, String, TrueClass, FalseClass, Symbol, Time
            true
          when Array
            value.all? { |element| serializable_value?(element) }
          when Hash
            value.values.all? { |element| serializable_value?(element) }
          else
            false
          end
        end
      end
    end
  end
end

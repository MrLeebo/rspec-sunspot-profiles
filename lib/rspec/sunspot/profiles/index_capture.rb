# frozen_string_literal: true

module RSpec
  module Sunspot
    module Profiles
      class IndexCapture
        CAPTURED_METHODS = %i[index index! add add!].freeze

        def initialize(sunspot: Object.const_defined?(:Sunspot) ? ::Sunspot : nil)
          @sunspot = sunspot
          @records = []
        end

        def evaluate(&block)
          with_capturing_session do
            block.call
          end

          @records.empty? ? {} : { "records" => @records }
        end

        private

        attr_reader :records, :sunspot

        def with_capturing_session
          return yield unless capturable_sunspot?

          original_session = sunspot.session
          sunspot.session = CapturingSession.new(original_session, method(:capture_records))
          yield
        ensure
          sunspot.session = original_session if capturable_sunspot?
        end

        def capturable_sunspot?
          sunspot && sunspot.respond_to?(:session) && sunspot.respond_to?(:session=)
        end

        def capture_records(*indexed_records)
          records.concat(indexed_records.flatten.compact.map { |record| serialize_record(record) })
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

      class CapturingSession
        def initialize(session, on_index:)
          @session = session
          @on_index = on_index
        end

        IndexCapture::CAPTURED_METHODS.each do |method_name|
          define_method(method_name) do |*records, **kwargs, &block|
            @on_index.call(*records)

            if kwargs.empty?
              @session.public_send(method_name, *records, &block)
            else
              @session.public_send(method_name, *records, **kwargs, &block)
            end
          end
        end

        def method_missing(method_name, *args, **kwargs, &block)
          if kwargs.empty?
            @session.public_send(method_name, *args, &block)
          else
            @session.public_send(method_name, *args, **kwargs, &block)
          end
        end

        def respond_to_missing?(method_name, include_private = false)
          @session.respond_to?(method_name, include_private) || super
        end
      end
    end
  end
end

# frozen_string_literal: true

module Hive
  class Service
    class AttributeValue
      AttributeBlank = Class.new(StandardError)
      AttributeWithWrongType = Class.new(StandardError)

      def initialize(value, options)
        @value = value
        @options = options
      end

      def call
        value = @value
        value = @options[:default] if value.nil? && @options[:default]
        type[value]
      rescue Dry::Types::CoercionError
        raise AttributeBlank if @value.nil? && @options[:required]

        raise AttributeWithWrongType
      end

      def type
        return @type if @type

        @type = determine_type(@options[:type])
        @type = @type.optional unless @options[:required]
        @type
      end

      def determine_type(type)
        case type
        when Dry::Types::Type then type
        when Array then Types::Array(determine_type(type.first))
        else Types.Instance(type)
        end
      end
    end
  end
end

# frozen_string_literal: true

module Hive
  class Service
    class Failure < StandardError
      attr_reader :errors

      def initialize(errors)
        super
        @errors = errors
      end

      def message
        "failed with errors #{errors.to_h}"
      end
    end
  end
end

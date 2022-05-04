# frozen_string_literal: true

module Hive
  class Service
    class Result < Dry::Struct
      attribute :success, Types::Bool
      attribute :result, Types::Any
      attribute :errors, Types.Instance(Errors) | Types::Nil

      def success?
        success
      end

      def failure?
        !success
      end

      def successful?
        success
      end
    end
  end
end

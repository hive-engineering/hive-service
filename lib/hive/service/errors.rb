# frozen_string_literal: true

module Hive
  class Service
    class Errors
      def initialize(service)
        @service_class = service.class
        @errors = {}
        @error_sources = {}
      end

      def add(name, type)
        return self if error?(name, type)

        name = name.to_sym
        @error_sources[name] ||= {}
        @error_sources[name][type] = @service_class

        @errors[name] ||= []
        @errors[name] << { type: type.to_sym }

        self
      end

      def [](key)
        @errors[key]
      end

      def ==(other)
        to_h == other.to_h
      end

      def to_h
        @errors
      end

      def empty?
        @errors.empty?
      end

      def error?(name, type)
        (self[name.to_sym] || []).any? { |error| error.fetch(:type) == type.to_sym }
      end

      def inspect
        "#{self.class} #{@errors}"
      end

      def merge(other)
        merge_errors(other.errors)
        merge_error_sources(other.error_sources)
        self
      end

      def full_details
        @errors.map do |key, errors|
          [key, errors.map { |error| { type: error[:type], message: translate_error(key, error[:type]) } }]
        end.to_h
      end

      def as_json(_options)
        to_h
      end

      protected

      attr_reader :errors, :error_sources

      private

      def merge_errors(other_errors)
        other_errors.each do |name, errors|
          @errors[name] ||= []
          @errors[name] = (@errors[name] + errors).uniq
        end
      end

      def merge_error_sources(other_error_sources)
        @error_sources = @error_sources.deep_merge(other_error_sources)
      end

      def translate_error(key, type)
        original_service_class = @error_sources[key][type]
        [@service_class, original_service_class]
          .uniq
          .map { |service_class| translate(key, type, service_class) }
          .select(&:itself)
          .first
      end

      def translate(name, type, service_class)
        prefix = service_class.to_s.underscore.tr('/', '.')
        key = [prefix, 'errors', name, type].join('.')
        I18n.exists?(key) && I18n.t(key)
      end
    end
  end
end

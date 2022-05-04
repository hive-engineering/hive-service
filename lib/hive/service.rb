# frozen_string_literal: true

require 'dry-types'
require 'dry-struct'
require 'i18n'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string/inflections'

require 'hive/service/version'
require 'hive/service/errors'
require 'hive/service/types'
require 'hive/service/result'
require 'hive/service/failure'
require 'hive/service/attribute_value'

module Hive
  class Service
    class Halt < StandardError; end

    def self.attribute(name, type:, required: false, default: nil)
      @attributes ||= {}
      @attributes[name] = { type:, required:, default: }
    end

    def self.attributes
      @attributes || {}
    end

    def self.attributes_names
      attributes.keys
    end

    def self.validations
      @validations ||= []
    end

    def self.validate(method, *args)
      validations.push([method, args]) unless validations.include?([method, args])
    end

    def self.run(attributes = {})
      new(attributes).run
    end

    def self.run!(attributes = {})
      outcome = run(attributes)
      raise Failure, outcome.errors unless outcome.success?

      outcome.result
    end

    def initialize(attributes = {})
      initialize_errors
      initialize_inputs(attributes)
      initialize_attributes
    end

    def run
      halt! unless valid?
      validate
      halt! unless valid?
      result = perform
      halt! unless valid?
      return_success(result)
    rescue Halt
      return_failure(@errors)
    end

    private

    def compose(other_service_class, params = {})
      outcome = other_service_class.run(params)
      return outcome.result if outcome.success?

      @errors.merge(outcome.errors)
      halt!
    end

    def add_error(name, error)
      @errors.add(name, error)
    end

    def add_error!(name, error)
      add_error(name, error)
      halt!
    end

    def validate
      self.class.validations.each { |method, _| send(method) }
    end

    def valid?
      @errors.empty?
    end

    def halt!
      raise Halt
    end

    def return_success(result)
      Result.new(result:, success: true, errors: nil)
    end

    def return_failure(errors)
      Result.new(result: nil, success: false, errors:)
    end

    def initialize_errors
      @errors = Errors.new(self)
    end

    def initialize_inputs(attributes)
      @inputs = attributes.deep_symbolize_keys
    end

    def initialize_attributes
      self.class.attributes.each { |name, options| initialize_attribute(name, options) }
    end

    def initialize_attribute(name, options)
      value = AttributeValue.new(@inputs[name], options).call

      instance_variable_set(:"@#{name}", value)
    rescue AttributeValue::AttributeBlank
      @errors.add(name, :blank)
    rescue AttributeValue::AttributeWithWrongType
      @errors.add(name, :wrong_type)
    end
  end
end

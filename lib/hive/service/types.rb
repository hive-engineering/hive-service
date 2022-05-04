# frozen_string_literal: true

module Hive
  class Service
    module Types
      include Dry::Types(:nominal, :coercible, :params, :strict, default: :params)

      Any = Nominal::Any
      String = Coercible::String
      Symbol = Coercible::Symbol
      Class = Strict::Class
    end
  end
end

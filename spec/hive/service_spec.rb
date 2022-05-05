# frozen_string_literal: true

# rubocop:disable RSpec/InstanceVariable, RSpec/LeakyConstantDeclaration, Lint/ConstantDefinitionInBlock

RSpec.describe Hive::Service do
  module Specs
    class SimpleService < ::Hive::Service
      attribute :some_attribute, type: Types::Any

      def perform
        'this is the result'
      end
    end

    class ServiceWithAttributes < ::Hive::Service
      attribute :string, type: Types::String
      attribute :integer, type: Types::Integer, required: true, default: 314
      attribute :date, type: Types::Date, default: '2019-10-10'
      attribute :time, type: Types::Time
      attribute :float, type: Types::Float
      attribute :bool, type: Types::Bool, required: false
      attribute :symbol, type: Types::Symbol, required: true

      def perform
        {
          string: @string,
          integer: @integer,
          date: @date,
          time: @time,
          float: @float,
          bool: @bool,
          symbol: @symbol
        }
      end
    end

    SomeClass = Class.new
    SomeClassChild = Class.new(SomeClass)
    class OtherClass
      def some_method; end
    end

    class ServiceWithClassType < ::Hive::Service
      attribute :some_attribute, type: SomeClass

      def perform; end
    end

    class ServiceWithInterfaceType < ::Hive::Service
      attribute :some_attribute, type: Types::Interface(:some_method)

      def perform; end
    end

    class ServiceWithHashType < ::Hive::Service
      attribute :hash, type: Types.Hash(name: Types::String, age: Types::Integer)

      def perform
        @hash
      end
    end

    class ServiceWithArrayType < ::Hive::Service
      attribute :array_with_class, type: [SomeClass]
      attribute :array_with_type, type: [Types::Integer], default: [1]
      attribute :array_dry_types, type: Types::Array(Types::Symbol)

      def perform
        {
          array_with_class: @array_with_class,
          array_with_type: @array_with_type,
          array_dry_types: @array_dry_types
        }
      end
    end

    class ServiceWithMethodValidation < ::Hive::Service
      validate :validation_method
      validate :other_validation_method

      def perform
        raise 'oh shit! ERRRRROOO!!'
      end

      private

      def validation_method
        add_error(:some_attribute, :validation_method_failed)
      end

      def other_validation_method
        add_error(:some_attribute, :other_method)
      end
    end

    class SomeSingleton
      def self.call; end
    end

    class ServiceThatCallsAddError < ::Hive::Service
      attribute :first, type: Types::Bool, default: false
      attribute :second, type: Types::Bool, default: false

      def perform
        add_error!(:base, :first_error) if @first
        add_error(:base, :second_error) if @second
        SomeSingleton.call
      end
    end

    class ServiceWithComposeInvalid < ::Hive::Service
      def perform
        compose ServiceWithMethodValidation
        SomeSingleton.call
      end
    end

    class ServiceWithComposeValid < ::Hive::Service
      def perform
        result = compose SimpleService
        result * 2
      end
    end
  end

  describe 'outcome' do
    let(:outcome) { Specs::SimpleService.run(some_attribute: :ok) }

    it 'returns Result object' do
      expect(outcome).to be_a Hive::Service::Result
    end

    it 'pass return value from #perform method to Result object' do
      expect(outcome.result).to eq 'this is the result'
    end
  end

  describe 'validations' do
    describe 'method validation' do
      let(:outcome) { Specs::ServiceWithMethodValidation.run }

      it 'is failure' do
        expect(outcome).to be_failure
      end

      it 'has correct errors' do
        expect(outcome.errors).to eq(some_attribute: [{ type: :validation_method_failed }, { type: :other_method }])
      end
    end
  end

  describe 'adding errors during perform' do
    let(:outcome) { Specs::ServiceThatCallsAddError.run(params) }

    context 'when add_error! is called' do
      let(:params) { { first: true } }

      it 'halts whole execution' do
        expect(Specs::SomeSingleton).not_to receive(:call)
        outcome
      end

      it 'is failure' do
        expect(outcome).to be_failure
      end

      it 'has error' do
        expect(outcome.errors).to eq(base: [type: :first_error])
      end
    end

    context 'when add_error is called' do
      let(:params) { { second: true } }

      it 'does not halt execution' do
        expect(Specs::SomeSingleton).to receive(:call)
        outcome
      end

      it 'is failure' do
        expect(outcome).to be_failure
      end

      it 'has error' do
        expect(outcome.errors).to eq(base: [type: :second_error])
      end
    end
  end

  describe 'composing' do
    context 'when composed service failed' do
      let(:outcome) { Specs::ServiceWithComposeInvalid.run }

      it 'is failure' do
        expect(outcome).to be_failure
      end

      it 'has merged errors' do
        expect(outcome.errors).to eq(some_attribute: [{ type: :validation_method_failed }, { type: :other_method }])
      end

      it 'halts execution' do
        expect(Specs::SomeSingleton).not_to receive(:call)
        outcome
      end
    end

    context 'when composed service succeded' do
      let(:outcome) { Specs::ServiceWithComposeValid.run }

      it 'is success' do
        expect(outcome).to be_success
      end

      it 'has access to returned value from composed operation' do
        expect(outcome.result).to eq 'this is the resultthis is the result'
      end
    end
  end

  describe 'run!' do
    context 'when service is failure' do
      it 'raise error' do
        expect { Specs::ServiceWithMethodValidation.run! }.to raise_error(::Hive::Service::Failure)
      end

      describe 'error' do
        it 'has correct message' do
          Specs::ServiceWithMethodValidation.run!
        rescue ::Hive::Service::Failure => e
          expect(e.message).to eq(
            'failed with errors {:some_attribute=>[{:type=>:validation_method_failed}, {:type=>:other_method}]}'
          )
        end

        it 'has errors' do
          Specs::ServiceWithMethodValidation.run!
        rescue ::Hive::Service::Failure => e
          expect(e.errors).to eq(some_attribute: [{ type: :validation_method_failed }, { type: :other_method }])
        end
      end
    end

    context 'when service is valid' do
      it 'returns the result' do
        expect(Specs::SimpleService.run!).to eq 'this is the result'
      end
    end
  end

  describe 'attributes' do
    let(:outcome) { Specs::ServiceWithAttributes.run(params) }

    context 'with invalid types' do
      let(:params) do
        {
          string: :string, integer: 'x', date: 'some-date',
          time: 'not-time', float: 'xxx', bool: 'notbool', symbol: 'symbol'
        }
      end

      it 'is failure' do
        expect(outcome).to be_failure
      end

      it 'has errors for each invalid type' do
        expect(outcome.errors).to eq(
          integer: [{ type: :wrong_type }],
          time: [{ type: :wrong_type }],
          float: [{ type: :wrong_type }],
          bool: [{ type: :wrong_type }],
          date: [{ type: :wrong_type }]
        )
      end
    end

    context 'with coercible types' do
      let(:params) do
        { string: :string, integer: '-123', date: '2019-10-10',
          time: '2019-10-10 10:10', float: '123.123', bool: 'true', symbol: 'symbol' }
      end

      it 'is success' do
        expect(outcome).to be_success
      end

      it 'coerces strings, integers, floats, dates, times, bools and symbols' do
        expect(outcome.result).to eq(
          string: 'string',
          integer: -123,
          date: Date.parse('2019-10-10'),
          time: Time.parse('2019-10-10 10:10'),
          float: 123.123,
          bool: true,
          symbol: :symbol
        )
      end
    end

    context 'when some attribute is missing' do
      context 'when required attribute is missing' do
        let(:params) do
          { integer: '-123', date: '2019-10-10', time: '2019-10-10 10:10', float: '123.123', bool: 'true' }
        end

        it 'is failure' do
          expect(outcome).to be_failure
        end

        it 'has error' do
          expect(outcome.errors).to eq(symbol: [type: :blank])
        end
      end

      context 'when required attribute is nil' do
        let(:params) do
          { integer: '-123', date: '2019-10-10', time: '2019-10-10 10:10', float: '123.123', bool: 'true', symbol: nil }
        end

        it 'is failure' do
          expect(outcome).to be_failure
        end

        it 'has error' do
          expect(outcome.errors).to eq(symbol: [type: :blank])
        end
      end

      context 'when required attribute is missing but it has default value' do
        let(:params) do
          { date: '2019-10-10', time: '2019-10-10 10:10', float: '123.123', bool: 'true', symbol: :symbol }
        end

        it 'is success' do
          expect(outcome).to be_success
        end

        it 'set default as value for attribute' do
          expect(outcome.result[:integer]).to eq 314
        end
      end

      context 'when optional attribute is missing' do
        let(:params) do
          { integer: '-123', date: '2019-10-10', time: '2019-10-10 10:10', symbol: :symbol }
        end

        it 'is success' do
          expect(outcome).to be_success
        end
      end

      context 'when optional attribute with default value is missing' do
        let(:params) do
          { integer: '-123', float: 3.14, time: '2019-10-10 10:10', symbol: :symbol }
        end

        it 'is success' do
          expect(outcome).to be_success
        end

        it 'set default (coerced) value for attribute' do
          expect(outcome.result[:date]).to eq Date.parse('2019-10-10')
        end
      end
    end

    context 'with class type' do
      let(:outcome) { Specs::ServiceWithClassType.run(params) }

      context 'when passed value is instance of given class' do
        let(:params) { { some_attribute: Specs::SomeClass.new } }

        it 'is success' do
          expect(outcome).to be_success
        end
      end

      context 'when passed value is instance of child of given class' do
        let(:params) { { some_attribute: Specs::SomeClassChild.new } }

        it 'is success' do
          expect(outcome).to be_success
        end
      end

      context 'when passed value is not instance of given class' do
        let(:params) { { some_attribute: Specs::OtherClass.new } }

        it 'is failure' do
          expect(outcome).to be_failure
        end

        it 'has error' do
          expect(outcome.errors).to eq(some_attribute: [type: :wrong_type])
        end
      end
    end

    context 'with interface type' do
      let(:outcome) { Specs::ServiceWithInterfaceType.run(params) }

      context 'when attribute does not respond to given method' do
        let(:params) { { some_attribute: Specs::SomeClass.new } }

        it 'is failure' do
          expect(outcome).to be_failure
        end

        it 'has error' do
          expect(outcome.errors).to eq(some_attribute: [type: :wrong_type])
        end
      end

      context 'when attribute responds to given method' do
        let(:params) { { some_attribute: Specs::OtherClass.new } }

        it 'is success' do
          expect(outcome).to be_success
        end
      end
    end

    context 'with hash type' do
      let(:outcome) { Specs::ServiceWithHashType.run(params) }

      context 'when attribute is not hash' do
        let(:params) { { hash: 123 } }

        it 'is failure' do
          expect(outcome).to be_failure
        end

        it 'has error' do
          expect(outcome.errors).to eq(hash: [type: :wrong_type])
        end
      end

      context 'when attribute is hash' do
        context 'when some nested elements do not have correct types' do
          let(:params) { { hash: { age: 'xxx', name: :'this-name' } } }

          it 'is failure' do
            expect(outcome).to be_failure
          end

          it 'has error' do
            expect(outcome.errors).to eq(hash: [type: :wrong_type])
          end
        end

        context 'when all members have correct types' do
          let(:params) { { hash: { 'age' => '123', 'name' => :'this-name' } } }

          it 'is success' do
            expect(outcome).to be_success
          end

          it 'coerces nested elements and symbolize keys' do
            expect(outcome.result).to eq(age: 123, name: 'this-name')
          end
        end
      end
    end

    context 'with any type' do
      let(:outcome) { Specs::SimpleService.run(params) }

      context 'when passing symbol type' do
        let(:params) { { some_attribute: :some_symbol } }

        it { expect(outcome).to be_success }
      end

      context 'when passing string type' do
        let(:params) { { some_attribute: 'some_string' } }

        it { expect(outcome).to be_success }
      end

      context 'when passing an object' do
        let(:params) { { some_attribute: Specs::SomeClass.new } }

        it { expect(outcome).to be_success }
      end
    end

    context 'with array type' do
      let(:outcome) { Specs::ServiceWithArrayType.run(params) }

      context 'when attribute is not array' do
        let(:params) { { array_with_class: {}, array_with_type: 'type', array_dry_types: 123 } }

        it 'is failure' do
          expect(outcome).to be_failure
        end

        it 'has errors' do
          expect(outcome.errors).to eq(
            array_with_class: [{ type: :wrong_type }],
            array_with_type: [{ type: :wrong_type }],
            array_dry_types: [{ type: :wrong_type }]
          )
        end
      end

      context 'when members of arrays have wrong types' do
        let(:params) { { array_with_class: [123], array_with_type: ['xxx'], array_dry_types: [-123] } }

        it 'is failure' do
          expect(outcome).to be_failure
        end

        it 'has errors' do
          expect(outcome.errors).to eq(
            array_with_class: [{ type: :wrong_type }],
            array_with_type: [{ type: :wrong_type }],
            array_dry_types: [{ type: :wrong_type }]
          )
        end
      end

      context 'when attributes are arrays with correct members' do
        let(:array_with_class) { [Specs::SomeClass.new, Specs::SomeClass.new] }

        let(:params) do
          {
            array_with_class:,
            array_with_type: ['1', 2, '3'],
            array_dry_types: ['symbol', :other_symbol]
          }
        end

        it 'is success' do
          expect(outcome).to be_success
        end

        it 'coerces array members' do
          expect(outcome.result).to eq(
            array_with_class:,
            array_with_type: [1, 2, 3],
            array_dry_types: %i(symbol other_symbol)
          )
        end
      end
    end
  end
end

# rubocop:enable RSpec/InstanceVariable, RSpec/LeakyConstantDeclaration, Lint/ConstantDefinitionInBlock

# Hive::Service

This gem aims to simplify and standardize the service interface to be used across the service layer in our ruby projects. It provides composition, typing, and built in validations to ensure that our complex service logic is both flexible and safe.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hive-service'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hive-service

## Usage

We need to create a base service that will inherit from `::Hive::Service`:

```ruby
class BaseService < ::Hive::Service

end
```

## .run

Example:

```ruby
class ExampleService < BaseService
  attribute :counter, type: Types::Integer, required: true

  validate :counter_not_exceeded

  def perform
    @counter + 1
  end

  private

  def counter_not_exceeded
    add_error(:counter, :exceeded) if @counter > 10
  end
end
```

Usage:
```ruby
ExampleService.run(counter: 9)

=> Hive::Service::Result.new(result: 10, errors: nil, success: true)
```

The following happens:
- It will validate that the counter can be coerced in to integer
- If not, execution will be halted and service will fail
- It will run `counter_not_exceeded` method (if validation passes)
- If the validation fails (counter > 10), `perform` method will not be executed and the service will **fail**
- If the validation passes `perform` method will be executed
- `Result` object will be returned with `success=true` and `result=counter+1`

Note that:
```ruby
ExampleService.run('counter' => 9)
```

is also a valid service invocation

## .run!

The `run!` method will raise an error `Hive::Service::Failure` if validation fails, otherwise it will return the returned value from the `perform` method without wrapping it in a `Result` object.

`Hive::Service::Failure` will have access to errors:

```ruby
begin
 ExampleService.run!('counter' => 11)
rescue Hive::Service::Failure => error
  error.errors.to_h
end

=> { counter: [type: :exceeded] }

```

## #compose

The `compose` method allows us to compose multiple services within a service.

Usage:

```ruby
def perform
  counter = @counter + 10
  new_counter = compose AnotherService, counter: counter, other_param: true
  new_counter + counter
end
```

It will:

- Call `AnotherService.run()` with given attributes
- If composed service fails **it will halt whole execution** and merge the errors with calling service's errors.
- If composed service succeeds it will return the unwrapped return value of the composed service's `perform` method

## Result object

Running the `run` method causes the service to return a `Result` object.

If the service succeeds:
- `Result` object will have `success=true`
- `Result` object will have returned value from `perform` method inside `result` attribute
- `Result` object will have empty `errors`

If the service fails:
- `Result` object will have `success=false`
- `Result` object will have `result=nil`
- `Result` object will have one or more errors in the `errors` attribute

## Errors

Each instance of this class will have `@errors`. At any point for lifecycle you can add errors.
After each step (validations, execution) service will check if there are some errors - if yes it will halt execution and return `Result` object

to add error use `add_error` method:

```ruby
add_error(:some_field, :this_is_an_error)
```

Note: this will add error but will not halt current step

To add error and halt execution immediately use:

```ruby
add_error!(:some_field, :this_is_error)
```

# Errors object

Errors object is similar to hash but with some adjustments.
If you only care about error values then you can run `#to_h`.
If you want also full messages or the translations then run `#full_details`.

It will return a hash similar to:

```ruby
{
  counter: {
    type: :exceeded,
    message: 'Counter was exceeded'
  }
}
```

This gem uses `I18n` for translation, it will look for a translation key as follows:
`[service_name].errors.[some_attribute].[error_name]`.

The `[service_name]` is the class of service name converted to under score like:

`SomeNamespace::SomeModule::ExampleService` -> `some_namespace.some_module.some_service`

For errors coming from composed services, it will try to find translation for **outer** (caller) service first
and then for **inner** (composed) service.

## Attributes

Attributes are validated/coerced using `Dry::Types`.

To define a type for an attribute use:
```ruby
attribute :some_attribute, type: Types::[some-type]
```

If the passed value has a different type the service will fail and add an error:
```ruby
 errors.add(:some_attribute, :wrong_type)
```

The value will be accessible by an **instance variable**: `@some_attribute`

So for example:

```ruby
attribute :cool_attribute, type: Types::Integer

def perform
  @cool_attribute + 1
end
```

It will be accessible by an instance method you define inside your service class.

By default `Types` module has imported coercible types, if you want to use strict ones (that will raise error if passed attribute does not have exactly same type) you need to call it explicitly by using `Strict`:

```ruby
attribute :some_attribute, type: Types::Strict::[some-type]
```

By default every attribute is **not required**. You can change that by passing `required: true` option to the attribute

```ruby
attribute :some_attribute, type: Types::String, required: true
```

In this case, if `some_attribute` will be missing service will add an error:

```ruby
 errors.add(:some_attribute, :blank)
```

You can also specify a default value for given attribute:

```ruby
attribute :some_attribute, type: Types::String, default: 'this is the default value'
```

If `some_attribute` will not be passed to service it will use the defined default value. _Default values will be coerced_.


### Basic types

|type|example coercion|
|---|---|
|Types::String| `123 -> '123'`, `:symbol -> 'symbol'`|
|Types::Symbol| `'symbol' -> :symbol`|
|Types::Integer| `'123' -> 123`, `123.13 -> 123`|
|Types::Float| `'123.123' -> 123.123`, `123 -> 123.0`|
|Types::Date| `'2010-10-10' -> Date.parse('2010-10-10')`|
|Types::Time| `'2010-10-10 10:10' -> Time.parse('2010-10-10 10:10')`|
|Types::Bool| `'false' -> false`, `'1' -> true`|

### Instance type

Instance can be used in two ways:
1) Pure `dry-types`
2) Pure class

|type|example|
|---|---|
|Types::Instance(SomeType) | `SomeType.new` |
|SomeType | `SomeType.new` |

The gem will wrap anything passed as `type` of attribute which is not a child of `Dry::Types::Type` (or `Array`) into `Types::Instance()`

### Array type

Array can be used in two ways:
1) Pure `dry-types`
2) Wrapped in syntax sugar

|type|example|
|---|---|
|`Types::Array(Types::Symbol)` | `[:symbol, 'other-symbol']` |
|`[Types::Symbol]` | `[:symbol, 'other-symbol']` |
|`[SomeType]` | `[SomeType.new]` |
|`Types::Array(Types::Instance(SomeType))` | `[SomeType.new]` |

Using syntax sugar will allow us to pass normal classes inside `[]` and this classes will be wrapped into
`Types::Instance()`

### Interface type

Interface type should be used with `dry-type` `Interface` syntax:

```ruby
attribute :some_attribute, type: Types::Interface(:some_method)
```

### Hash type

Interface type should be used with `dry-type` `Hash` sytnax:

```ruby
attribute :some_attribute, type: Types::Hash(some_key: Types::Integer)
```

Note if you want to use classes for nested types then you need to wrap it into `Types::Instance()`

### Any type

Any type should be used with `dry-type` `Any` syntax:

```ruby
attribute :some_attribute, type: Types::Any
```

The use of `Any` type should be limited as much as possible since it opposes the whole concept of typing in the first place!

### Any any type

You can use any type that comes from `dry-types`. For reference please see: [dry-types](https://dry-rb.org/gems/dry-types/1.2/built-in-types/)

### Examples

You can find implementation examples in `spec/hive/service_spec.rb`


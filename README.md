# HashSchema [![Gem Version](https://badge.fury.io/rb/hash_schema.svg)](http://badge.fury.io/rb/hash_schema)

A ruby gem that validates Hash against some schema, works for hashes created from loading json and yml files, and suchlike

## Installation

Add this line to your application's Gemfile:

    gem 'hash_schema'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hash_schema

## Usage

### What it is / isn't for

It is for:

- validating structure
    - e.g. a hash contains keys "greetings" and "name", and "name" is an inner hash that contains "give", "family" and "other"
        - { "greetings": "Hello", "name": { "given": "John", "family": "Doe", "other": "" } }
- validating data type
    - e.g. { "offset": [7, 8] }, where "offset" has to be an array of numbers
- validating constants
    - e.g. some value has to be set to `true`

It is **not** for:

- validating dependency
    - e.g. key A has to exist if key B exists

[Jump down to see detailed example](#demo)

### Defined schemas

#### StringSchema

- `.new`
    - takes no arguments
- `#validate` :: (String|\*) -> (*Null*|error)

#### NumberSchema

- `.new`
    - takes no arguments
- `#validate` :: (Number|\*) -> (*Null*|error)

#### BooleanSchema

- `.new`
    - takes no arguments
- `#validate` :: (Boolean|\*) -> (*Null*|error)

#### EnumSchema

- `.new`
    - takes literal constants, e.g. 123, "456", false, true...
- `#validate` :: (\*) -> (*Null*|error)
    - An inclusion check is performed

#### OptionalSchema

- `.new`
    - takes a Schema or literal constant
- `#validate` :: (Void|\*) -> (*Null*|error)
    - `Void.new` is the internal representation of `Nothing`
    - if anything other than `Void.new` is given
        - it is delegated to the Schema, if a Schema was given when initializing
        - it performs equality check, if initialized with anything other than a Schema

#### OrSchema

- `.new`
    - takes multiple Schemas
- `#validate` :: (\*) -> (*Null*|error)
    - it passes if any of the given Schema passes
    - it errors if all of the given Schema end up with error

#### ArraySchema

- `.new`
    - takes one Schemas
- `#validate` :: (Array|\*) -> (**Array**|error)
    - it errors if the arugment passed to `#validate` is not an array
    - it maps the Schema validation over the elements in the array
    - it returns the mapped-over array

#### HashSchema

- `.new`
    - takes keywords, see `#1`
    - other than Schemas, you can also specify literal constants like in `#2`
    - you can specify `strict` mode if you want to see errors for not specified keys
    - if you have the key `strict` in your data hash, see `#3`

```ruby
#1
HashSchema.new(a: NumberSchema.new, b: BooleanSchema.new, c: StringSchema.new)

#2
HashSchema.new(strict: true,
  number: 1,
  boolean: true,
  string: 'string',
  ampm_array: ArraySchema.new(EnumSchema.new('am', 'pm'))
)

#3
HashSchema.new(strict: true,
  schema_hash: {
    strict: 'I am strict'
  }
)
```

- `#valdiate` :: (Hash|\*) -> (**Hash**|error)
- `#pretty_validate` :: (Hash|\*) -> String **(*)**
- `#interpret` :: (Hash|\*) -> [String]

**(*)** `#pretty_validate` is just a `JSON.pretty_generate` wrapper of `#validate`

*See below for more details*

### Demo

*Demo Setup*

```ruby
require 'json'
require 'hash_schema'

class Test
  include HashSchema

  Definition = HashSchema.new(
    string_good: StringSchema.new,
    string_bad: StringSchema.new,
    number_good: NumberSchema.new,
    number_bad: NumberSchema.new,
    boolean_good: BooleanSchema.new,
    boolean_bad: BooleanSchema.new,
    enum_good1: EnumSchema.new('z', 0),
    enum_good2: EnumSchema.new('z', 0),
    enum_bad: EnumSchema.new('z', 0),
    optional_good: OptionalSchema.new(1),
    optional_bad: OptionalSchema.new(1),
    optional_key_missing: OptionalSchema.new(1),
    mandatory_key_missing: 'value',
    or_good1: OrSchema.new(StringSchema.new, NumberSchema.new),
    or_good2: OrSchema.new(StringSchema.new, NumberSchema.new),
    or_bad: OrSchema.new(StringSchema.new, NumberSchema.new),
    array_good: ArraySchema.new(NumberSchema.new),
    array_bad: ArraySchema.new(NumberSchema.new),
    object_array_good: ArraySchema.new(HashSchema.new(x: NumberSchema.new, y: NumberSchema.new)),
    object_array_bad: ArraySchema.new(HashSchema.new(x: NumberSchema.new, y: NumberSchema.new)),
    object_array_missing: ArraySchema.new(HashSchema.new(x: NumberSchema.new, y: NumberSchema.new)),
    nested_hash: HashSchema.new(string: 'xyz', number: 987, boolean: true),
    nested_hash_missing: HashSchema.new
  )
end

data = {
  string_good: '123',
  string_bad: 123,
  number_good: 456,
  number_bad: '456',
  boolean_good: true,
  boolean_bad: 'false',
  enum_good1: 'z',
  enum_good2: 0,
  enum_bad: 'a',
  optional_good: 1,
  optional_bad: 2,
  or_good1: 'abc',
  or_good2: 123,
  or_bad: false,
  array_good: [0.5, 3.1, 4.2, 8],
  array_bad: [nil, 'a', false],
  object_array_good: [{ x: 0.5, y: 0.3 }, { x: 4, y: 3 }],
  object_array_bad: [{ x: 3 }, { y: 4 }],
  nested_hash: {}
}
```

*Demo output*

```ruby
puts Test::Definition.pretty_validate(data) # outputs the following
```

    {
      "string_good": null,
      "string_bad": "Expected String but got 123",
      "number_good": null,
      "number_bad": "Expected Number but got \"456\"",
      "boolean_good": null,
      "boolean_bad": "Expected Boolean but got \"false\"",
      "enum_good1": null,
      "enum_good2": null,
      "enum_bad": "Expected \"z\" or 0 but got \"a\"",
      "optional_good": null,
      "optional_bad": "Expected 1 but got 2",
      "optional_key_missing": null,
      "mandatory_key_missing": "Expected \"value\" but got Nothing",
      "or_good1": null,
      "or_good2": null,
      "or_bad": "Expected String or Number but got false",
      "array_good": [
        null,
        null,
        null,
        null
      ],
      "array_bad": [
        "Expected Number but got nil",
        "Expected Number but got \"a\"",
        "Expected Number but got false"
      ],
      "object_array_good": [
        {
          "x": null,
          "y": null
        },
        {
          "x": null,
          "y": null
        }
      ],
      "object_array_bad": [
        {
          "x": null,
          "y": "Expected Number but got Nothing"
        },
        {
          "x": "Expected Number but got Nothing",
          "y": null
        }
      ],
      "object_array_missing": "Expected [Hash] but got Nothing",
      "nested_hash": {
        "string": "Expected \"xyz\" but got Nothing",
        "number": "Expected 987 but got Nothing",
        "boolean": "Expected true but got Nothing"
      },
      "nested_hash_missing": "Expected Hash but got Nothing"
    }

```ruby
puts Test::Definition.interpret(data) # outputs the following
```

    root:{} > .string_bad > Expected String but got 123
    root:{} > .number_bad > Expected Number but got "456"
    root:{} > .boolean_bad > Expected Boolean but got "false"
    root:{} > .enum_bad > Expected "z" or 0 but got "a"
    root:{} > .optional_bad > Expected 1 but got 2
    root:{} > .mandatory_key_missing > Expected "value" but got Nothing
    root:{} > .or_bad > Expected String or Number but got false
    root:{} > array_bad:[] > #0 > Expected Number but got nil
    root:{} > array_bad:[] > #1 > Expected Number but got "a"
    root:{} > array_bad:[] > #2 > Expected Number but got false
    root:{} > object_array_bad:[] > #0:{} > .y > Expected Number but got Nothing
    root:{} > object_array_bad:[] > #1:{} > .x > Expected Number but got Nothing
    root:{} > .object_array_missing > Expected [Hash] but got Nothing
    root:{} > nested_hash:{} > .string > Expected "xyz" but got Nothing
    root:{} > nested_hash:{} > .number > Expected 987 but got Nothing
    root:{} > nested_hash:{} > .boolean > Expected true but got Nothing
    root:{} > .nested_hash_missing > Expected Hash but got Nothing

## Contributing

1. Fork it ( https://github.com/[my-github-username]/hash_schema/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

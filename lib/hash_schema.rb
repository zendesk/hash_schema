require "hash_schema/version"

module HashSchema
  class Schema
    def initialize(chain = nil)
      @chain = chain
    end

    def interpret(data)
      (@interpretations = []).tap do |_|
        interpret_errors(validate(data), 'root')
      end
    end

    attr_reader :chain

    def pretty_validate(data)
      require 'json'
      JSON.pretty_generate(validate(data))
    end

    def expectation
      self.class.name.split('::').last.sub('Schema', '')
    end

    protected

    def error(data)
      expect(expectation, data)
    end

    def expect(wanted, unwanted)
      "Expected #{wanted} but got #{unwanted.inspect}"
    end

    private

    def interpret_errors(errors, *prefixes)
      *prefixes, prefix = prefixes
      prefixes <<= format(errors, prefix)

      case errors
        when Hash
          errors.each do |key, val|
            next if val.nil?
            interpret_errors(val, *prefixes, key)
          end
        when Array
          errors.each_with_index do |val, index|
            next if val.nil?
            interpret_errors(val, *prefixes, index)
          end
        when String
          @interpretations << (prefixes << errors).join(' > ')
      end
    end

    def format(error, name)
      if name.kind_of?(Numeric)
        name = "##{name}"
        return name if error.is_a?(String)
      end

      case error
        when Hash
          "#{name}:{}"
        when Array
          "#{name}:[]"
        when String
          ".#{name}"
      end
    end
  end

  class OptionalSchema < Schema
    def validate(data)
      return if data.is_a?(Void)
      return chain.validate(data) if chain.kind_of?(Schema)
      expect(chain.inspect, data) unless chain == data
    end
  end

  class OrSchema < Schema
    def initialize(*schemas)
      @chain = schemas
    end

    def validate(data)
      empty_error = true
      last_error = nil
      chain.each do |schema|
        next unless schema_matches_data_type(schema, data)
        last_error = schema.validate(data)
        empty_error = recursive_empty_error?(last_error)
        break if empty_error
      end
      if empty_error
        last_error
      else
        error(data)
      end
    end

    def expectation
      *names, name = chain.map(&:expectation)
      names.join(', ') << " or #{name}"
    end

    private

    def recursive_empty_error?(error)
      case error
      when Array
        true if error.compact.empty?
      when NilClass
        true
      when String
        false
      when Hash
        true if recursive_flat_hash_values(error).empty?
      else
        false
      end
    end

    def schema_matches_data_type(schema, data)
      case schema
      when ArraySchema
        data.is_a? Array
      when HashSchema
        data.is_a? Hash
      else
        true
      end
    end

    def recursive_flat_hash_values(hash)
      if hash.is_a? Hash
        hash.values.map do |value|
          recursive_flat_hash_values(value)
        end.flatten.compact
      else
        hash
      end
    end
  end

  class StringSchema < Schema
    def validate(data)
      return if data.is_a?(String)
      error(data)
    end
  end

  class NumberSchema < Schema
    def validate(data)
      return if data.kind_of?(Numeric)
      error(data)
    end
  end

  class BooleanSchema < Schema
    def validate(data)
      return if data.is_a?(TrueClass) || data.is_a?(FalseClass)
      error(data)
    end
  end

  class ArraySchema < Schema
    def validate(data)
      return data.map { |item| chain.validate(item) } if data.is_a?(Array)
      error(data)
    end

    def expectation
      "[#{chain.expectation}]"
    end
  end

  class EnumSchema < Schema
    def initialize(*enum)
      @chain = enum
    end

    def validate(data)
      return if chain.include?(data)
      error(data)
    end

    def expectation
      *vals, val = chain.map(&:inspect)
      vals.join(', ') << " or #{val}"
    end
  end

  class HashSchema < Schema
    def initialize(strict: false, schema_hash: {}, **keywords)
      @chain = schema_hash.merge(keywords)
      @strict = strict
    end

    def validate(hash)
      return error(hash) unless hash.is_a?(Hash)
      {}.tap do |output|
        chain.each do |key, schema|
          val = hash.fetch(key, hash.fetch(key.to_s, Void.new))
          output[key] = if schema.kind_of?(Schema)
            schema.validate(val)
          else
            schema == val ? nil : expect(schema.inspect, val)
          end
        end

        output.merge!((hash.keys - chain.keys).map { |k| [k, unexpected(k)] }.to_h) if @strict
      end
    end

    def unexpected(key)
      "Unexpected key: #{key.to_s.inspect}"
    end
  end

  private

  class Void
    def to_s
      'Nothing'
    end

    alias :inspect :to_s
  end
end

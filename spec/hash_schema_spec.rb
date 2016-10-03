require 'spec_helper'

describe HashSchema do
  Testers = ['abc123', 123, true, HashSchema::Void.new]

  def except(type)
    Testers.reject { |tester| tester.is_a? type }
  end

  describe HashSchema::StringSchema do
    subject { HashSchema::StringSchema }

    it 'passes for String type value' do
      expect(subject.new.validate('abc123!@#$%^&*()_=-+')).to be_nil
    end

    it 'fails for other types' do
      except(String).each do |tester|
        expect(subject.new.validate(tester)).to_not be_nil
      end
    end
  end

  describe HashSchema::NumberSchema do
    subject { HashSchema::NumberSchema }

    it 'passes for Numeric type value' do
      expect(subject.new.validate(1234567890)).to be_nil
    end

    it 'fails for other types' do
      except(Numeric).each do |tester|
        expect(subject.new.validate(tester)).to_not be_nil
      end
    end
  end

  describe HashSchema::BooleanSchema do
    subject { HashSchema::BooleanSchema }

    it 'passes for Boolean type value' do
      expect(subject.new.validate(true)).to be_nil
    end

    it 'fails for other types' do
      except(TrueClass).each do |tester|
        expect(subject.new.validate(tester)).to_not be_nil
      end
    end
  end

  describe HashSchema::OptionalSchema do
    subject { HashSchema::OptionalSchema }

    it 'passes for Void type value' do
      expect(subject.new.validate(HashSchema::Void.new)).to be_nil
    end

    context 'when initialized with a Schema' do
      it 'delegates to the inner Schema' do
        schema = Class.new(HashSchema::Schema).new

        expect(schema).to receive(:validate)

        subject.new(schema).validate(1)
      end
    end

    context 'when initialized with literal value' do
      it 'passes for the exact value' do
        expect(subject.new(1).validate(1)).to be_nil
      end

      it 'fails for different value' do
        expect(subject.new(1).validate(2)).to_not be_nil
      end
    end
  end

  describe HashSchema::EnumSchema do
    subject { HashSchema::EnumSchema.new(1, 'a', true) }

    it 'passes for provided literal values' do
      expect(subject.validate(1)).to be_nil
    end

    it 'passes for provided literal values' do
      expect(subject.validate('a')).to be_nil
    end

    it 'passes for provided literal values' do
      expect(subject.validate(true)).to be_nil
    end

    it 'fails for other values' do
      expect(subject.validate(2)).to_not be_nil
    end

    it 'fails for other values' do
      expect(subject.validate('b')).to_not be_nil
    end

    it 'fails for other values' do
      expect(subject.validate(false)).to_not be_nil
    end
  end

  describe HashSchema::OrSchema do
    subject { HashSchema::OrSchema }

    let(:multitype) do
      subject.new(
        HashSchema::NumberSchema.new,
        HashSchema::StringSchema.new,
        HashSchema::ArraySchema.new(HashSchema::StringSchema.new),
        HashSchema::ArraySchema.new(HashSchema::NumberSchema.new),
        HashSchema::HashSchema.new(boolean: HashSchema::BooleanSchema),
        HashSchema::HashSchema.new
      )
    end

    it 'passes if any inner schema passes' do
      expect(multitype.validate(1)).to be_nil
    end

    it 'passes if any inner schema passes' do
      expect(multitype.validate('a')).to be_nil
    end

    context 'when having inner ArraySchema or HashSchema' do
      it 'delegates to given ArraySchema for array' do
        expect(multitype.validate([])).to be_a(Array)
      end

      it 'delegates to given HashSchema for hash' do
        expect(multitype.validate(boolean: true)).to be_a(Hash)
      end

      it 'delegates to more than one inner ArraySchema' do
        validation_result = multitype.validate([1, 2, 3])
        expect(validation_result).to be_a(Array)
        expect(validation_result.compact).to be_empty
      end

      it 'delegates to more than one inner HashSchema' do
        validation_result = multitype.validate(boolean: 5)
        expect(validation_result).to be_a(Hash)
        expect(validation_result.values.compact).to be_empty
      end
    end

    it 'fails if all inner schema fail' do
      expect(multitype.validate(false)).to_not be_nil
    end
  end

  describe HashSchema::ArraySchema do
    subject { HashSchema::ArraySchema }

    let(:string_array) { ['a', 'b', 'c', 'd'] }
    let(:chaos_array) { ['a', 1, false, [], {}] }
    let(:string_array_schema) { subject.new(HashSchema::StringSchema.new) }
    let(:hash_array_schema) { subject.new(HashSchema::HashSchema.new) }

    it 'passes for array of the given type' do
      expect(string_array_schema.validate(string_array).compact).to eq([])
    end

    it 'fails for non-array input' do
      expect(string_array_schema.validate(123)).to_not be_nil
    end

    it 'handles nested structure' do
      expect(hash_array_schema.validate([{}, { x: 1 }, { y: 2 }])).to eq([{}, {}, {}])
    end

    it 'fails for array containing values not being the given type' do
      expect(string_array_schema.validate(chaos_array).compact.size).to eq(4)
    end
  end

  describe HashSchema::HashSchema do
    subject { HashSchema::HashSchema }

    it 'passes if all literal attributes pass' do
      schema = subject.new(
        string: HashSchema::StringSchema.new,
        number: HashSchema::NumberSchema.new,
        boolean: HashSchema::BooleanSchema.new,
        nothing: HashSchema::OptionalSchema.new,
        enum: HashSchema::EnumSchema.new(1, 'a', true)
      )

      data = {
        string: 'abc',
        number: 123,
        boolean: true,
        enum: 'a'
      }

      expect(schema.validate(data).reject { |_, v| v.nil? }).to be_empty
    end

    it 'handles nested structure' do
      schema = subject.new(
        hash: subject.new(
          literal: 1
        )
      )

      data = {
        hash: {
          literal: 1
        }
      }

      expect(schema.validate(data)).to eq({ hash: { literal: nil } })
    end

    it 'handles nested structure' do
      schema = subject.new(
        array: HashSchema::ArraySchema.new(HashSchema::BooleanSchema.new)
      )

      data = {
        array: [true, false]
      }

      expect(schema.validate(data)).to eq({ array: [nil, nil] })
    end

    it 'fails for non-hash input' do
      expect(subject.new.validate(123)).to_not be_nil
    end

    context 'when strict mode' do
      it 'fails for extra attributes' do
        schema = subject.new(strict: true, x: 0)

        data = { x: 0, y: 1 }

        expect(schema.validate(data).reject { |_, v| v.nil? }).to include(:y)
      end
    end

    context 'when hash keys contain "strict"' do
      it 'works around by passing the whole hash as "schema_hash"' do
        schema = subject.new(strict: true, schema_hash: { strict: HashSchema::NumberSchema.new })

        data = { strict: 1 }

        expect(schema.validate(data).reject { |_, v| v.nil? }).to be_empty
      end
    end
  end
end

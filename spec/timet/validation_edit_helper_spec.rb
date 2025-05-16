# frozen_string_literal: true

require 'rspec'
require 'timet/time_helper'
require 'timet/item_data_helper'
require 'timet/time_update_helper'

RSpec.describe Timet::ValidationEditHelper do
  subject(:validation_helper) do
    Class.new do
      include Timet::ValidationEditHelper
      attr_reader :db

      def initialize(db)
        @db = db
      end
    end.new(db)
  end

  let(:db) { instance_spy(Timet::Database) }
  let(:item) { [1, 1_728_414_793, 1_728_416_293] }
  let(:field_data) { { field: 'notes', new_value: 'Updated notes' } }
  let(:time_field_data) { { time_field: 'start', date_value: '2024-10-01 12:00:00' } }
  let(:time_value) { '11:10:00' }

  describe '#validate_and_update' do
    before do
      allow(db).to receive(:update_item)
      allow(db).to receive(:find_item).and_return(item)
    end

    context 'when field is a time field' do
      it 'raises ArgumentError for invalid date value' do
        time_field_data[:date_value] = 'invalid-time'
        expect do
          validation_helper.validate_and_update(
            item, time_field_data[:time_field], time_field_data[:date_value]
          )
        end.to raise_error(ArgumentError, /Invalid time format: invalid-time/)
      end

      it 'updates the item for valid date value' do
        valid_time_str = '10:30:00'

        original_start_time_obj = Time.at(item[1])
        new_time_components = Time.parse(valid_time_str)

        expected_datetime = Time.new(
          original_start_time_obj.year,
          original_start_time_obj.month,
          original_start_time_obj.day,
          new_time_components.hour,
          new_time_components.min,
          new_time_components.sec,
          original_start_time_obj.utc_offset
        )
        expected_timestamp = expected_datetime.to_i

        updated_item = validation_helper.validate_and_update(item, 'start', valid_time_str)
        expect(updated_item[1]).to eq(expected_timestamp)
      end
    end

    context 'when field is not a time field' do
      it 'updates the item directly' do
        field = field_data[:field]
        new_value = field_data[:new_value]
        updated_item = validation_helper.validate_and_update(item, field, new_value)

        expect(updated_item[4]).to eq(new_value)
      end
    end
  end
end

RSpec.describe Timet::TimeUpdateHelper do
  subject(:time_update_helper) do
    Class.new do
      include Timet::TimeUpdateHelper
      attr_reader :db

      def initialize(db)
        @db = db
      end
    end.new(db)
  end

  let(:db) { instance_spy(Timet::Database) }
  let(:item) { [1, 1_728_414_793, 1_728_416_293] }
  let(:time_field_data) { { time_field: 'start', date_value: '2024-10-01 12:00:00' } }
  let(:time_value) { '11:10:00' }

  describe '#update_time_field' do
    it 'updates the time field with the formatted date value' do
      # Mock Timet::Application::FIELD_INDEX if necessary for this test
      stub_const('Timet::Application::FIELD_INDEX', { 'start' => 1, 'end' => 2 })
      expect(
        time_update_helper.update_time_field(item, time_field_data[:time_field], time_value)
      ).to be_a(Time)
    end
  end

  describe '#process_and_update_time_field' do
    context 'when date_value is valid' do
      let(:current_time) { Time.now }
      let(:test_data) do
        {
          item: [1, current_time.to_i],
          next_item: { Timet::Application::FIELD_INDEX['start'] => current_time.to_i },
          prev_item: { Timet::Application::FIELD_INDEX['end'] => current_time.to_i },
          time_field: 'start',
          date_value: current_time.strftime('%H:%M:%S')
        }
      end

      before do
        stub_const('Timet::Application::FIELD_INDEX', { 'start' => 1, 'end' => 2 })
        allow(db).to receive(:find_item).with(test_data[:item][0] + 1).and_return(test_data[:next_item])
        allow(db).to receive(:find_item).with(test_data[:item][0] - 1).and_return(test_data[:prev_item])
        allow(db).to receive(:update_item)
        allow(Timet::TimeHelper).to receive_messages(current_timestamp: current_time.to_i,
                                                     format_time_string: test_data[:date_value])
        time_update_helper.instance_variable_set(:@db, db)
      end

      it 'updates the time field' do
        time_update_helper.process_and_update_time_field(test_data[:item], test_data[:time_field],
                                                         test_data[:date_value], test_data[:item][0])

        expect(db).to have_received(:update_item).with(
          test_data[:item][0],
          test_data[:time_field],
          kind_of(Integer)
        )
      end
    end

    context 'when date_value is invalid' do
      it 'prints an error message' do
        allow(Timet::TimeHelper).to receive(:format_time_string).and_return(nil)
        expect do
          time_update_helper.process_and_update_time_field(item, time_field_data[:time_field], 'invalid-time',
                                                           item[0])
        end.to output(/Invalid date: invalid-time/).to_stdout
      end
    end
  end

  describe '#print_error' do
    it 'prints an error message' do
      expect do
        time_update_helper.print_error('test error')
      end.to output("\e[38;5;1mInvalid date: test error\e[0m\n").to_stdout
    end
  end

  describe '#valid_time_value?' do
    context 'when field is start' do
      before do
        stub_const('Timet::Application::FIELD_INDEX', { 'start' => 1, 'end' => 2 })
        allow(db).to receive(:find_item).with(item[0] - 1).and_return([2, 1_728_414_000, 1_728_414_793])
        allow(db).to receive(:find_item).with(item[0] + 1).and_return([3, 1_728_416_293, 1_728_417_000])
      end

      it 'returns true if new_value_epoch is within valid range' do
        expect(time_update_helper.valid_time_value?(item, 'start', 1_728_415_000, item[0])).to be true
      end

      it 'returns false if new_value_epoch is outside valid range' do
        expect(time_update_helper.valid_time_value?(item, 'start', 1_728_414_000, item[0])).to be false
      end
    end

    context 'when field is end' do
      before do
        stub_const('Timet::Application::FIELD_INDEX', { 'start' => 1, 'end' => 2 })
        allow(db).to receive(:find_item).with(item[0] - 1).and_return([2, 1_728_414_000, 1_728_414_793])
        allow(db).to receive(:find_item).with(item[0] + 1).and_return([3, 1_728_416_293, 1_728_417_000])
      end

      it 'returns true if new_value_epoch is within valid range' do
        expect(time_update_helper.valid_time_value?(item, 'end', 1_728_415_000, item[0])).to be true
      end

      it 'returns false if new_value_epoch is outside valid range' do
        expect(time_update_helper.valid_time_value?(item, 'end', 1_728_417_000, item[0])).to be false
      end
    end
  end
end

RSpec.describe Timet::ItemDataHelper do
  let(:db) { instance_spy(Timet::Database) }
  let(:item) { [1, 1_728_414_793, 1_728_416_293] }

  describe '#fetch_item_start' do
    it 'returns the start time of the item' do
      stub_const('Timet::Application::FIELD_INDEX', { 'start' => 1 })
      expect(described_class.fetch_item_start(item)).to eq(item[1])
    end
  end

  describe '#fetch_item_end' do
    it 'returns the end time of the item' do
      stub_const('Timet::Application::FIELD_INDEX', { 'end' => 2 })
      allow(Timet::TimeHelper).to receive(:current_timestamp).and_return(1_728_416_293)
      expect(described_class.fetch_item_end(item)).to eq(item[2])
    end
  end

  describe '#fetch_item_before_end' do
    it 'returns the end time of the previous item' do
      stub_const('Timet::Application::FIELD_INDEX', { 'end' => 2 })
      allow(db).to receive(:find_item).and_return([1, 1_728_414_793, 1_728_416_293])
      expect(described_class.fetch_item_before_end(db, item[0], item[1])).to eq(1_728_416_293)
    end
  end

  describe '#fetch_item_after_start' do
    it 'returns the start time of the next item' do
      stub_const('Timet::Application::FIELD_INDEX', { 'start' => 1 })
      allow(db).to receive(:find_item).and_return([1, 1_728_414_793, 1_728_416_293])
      expect(described_class.fetch_item_after_start(db, item[0])).to eq(1_728_414_793)
    end
  end
end

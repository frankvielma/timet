# frozen_string_literal: true

require 'rspec'
require 'timet/time_helper'

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

    context 'when new_value is nil' do
      it 'returns nil' do
        expect(
          validation_helper.validate_and_update(item, field_data[:field], nil)
        ).to be_nil
      end
    end

    context 'when field is a time field' do
      it 'prints error to stdout for invalid date value' do
        time_field_data[:date_value] = 'invalid-time'
        expect do
          validation_helper.validate_and_update(
            item, time_field_data[:time_field], time_field_data[:date_value]
          )
        end.to output(/Invalid date: invalid-time/).to_stdout
      end
    end

    context 'when field is not a time field' do
      it 'updates the item directly' do
        validation_helper.validate_and_update(
          item, field_data[:field], field_data[:new_value]
        )
        expect(db).to have_received(:update_item).with(
          item[0], field_data[:field], field_data[:new_value]
        )
      end
    end
  end

  describe '#update_time_field' do
    it 'updates the time field with the formatted date value' do
      expect(
        validation_helper.send(
          :update_time_field, item, time_field_data[:time_field], time_value
        )
      ).to be_a(Time)
    end
  end

  describe '#process_and_update_time_field' do
    context 'when date_value is valid' do
      it 'updates the time field' do
        allow(validation_helper).to receive_messages(update_time_field: Time.now, valid_time_value?: true)
        validation_helper.send(:process_and_update_time_field, item, time_field_data[:time_field],
                               time_field_data[:date_value], item[0])
        expect(db).to have_received(:update_item).with(item[0], time_field_data[:time_field], Time.now.to_i)
      end
    end

    context 'when date_value is invalid' do
      it 'prints an error message' do
        allow(Timet::TimeHelper).to receive(:format_time_string).and_return(nil)
        expect do
          validation_helper.send(:process_and_update_time_field, item, time_field_data[:time_field], 'invalid-time',
                                 item[0])
        end.to output(/Invalid date: invalid-time/).to_stdout
      end
    end
  end

  describe '#print_error' do
    it 'prints an error message' do
      expect do
        validation_helper.send(:print_error, 'test error')
      end.to output("\e[38;5;1mInvalid date: test error\e[0m\n").to_stdout
    end
  end

  describe '#valid_time_value?' do
    context 'when field is start' do
      before do
        allow(db).to receive(:find_item).with(item[0] - 1).and_return([2, 1_728_414_000, 1_728_414_793])
        allow(db).to receive(:find_item).with(item[0] + 1).and_return([3, 1_728_416_293, 1_728_417_000])
      end

      it 'returns true if new_value_epoch is within valid range' do
        expect(validation_helper.send(:valid_time_value?, item, 'start', 1_728_415_000, item[0])).to be true
      end

      it 'returns false if new_value_epoch is outside valid range' do
        expect(validation_helper.send(:valid_time_value?, item, 'start', 1_728_414_000, item[0])).to be false
      end
    end

    context 'when field is end' do
      before do
        allow(db).to receive(:find_item).with(item[0] - 1).and_return([2, 1_728_414_000, 1_728_414_793])
        allow(db).to receive(:find_item).with(item[0] + 1).and_return([3, 1_728_416_293, 1_728_417_000])
      end

      it 'returns true if new_value_epoch is within valid range' do
        expect(validation_helper.send(:valid_time_value?, item, 'end', 1_728_415_000, item[0])).to be true
      end

      it 'returns false if new_value_epoch is outside valid range' do
        expect(validation_helper.send(:valid_time_value?, item, 'end', 1_728_417_000, item[0])).to be false
      end
    end
  end

  describe '#fetch_item_start' do
    it 'returns the start time of the item' do
      expect(validation_helper.send(:fetch_item_start, item)).to eq(item[1])
    end
  end

  describe '#fetch_item_end' do
    it 'returns the end time of the item' do
      expect(validation_helper.send(:fetch_item_end, item)).to eq(item[2])
    end
  end

  describe '#fetch_item_before_end' do
    it 'returns the end time of the previous item' do
      allow(db).to receive(:find_item).and_return([1, 1_728_414_793, 1_728_416_293])
      expect(validation_helper.send(:fetch_item_before_end, item[0], item[1])).to eq(1_728_416_293)
    end
  end

  describe '#fetch_item_after_start' do
    it 'returns the start time of the next item' do
      allow(db).to receive(:find_item).and_return([1, 1_728_414_793, 1_728_416_293])
      expect(validation_helper.send(:fetch_item_after_start, item[0])).to eq(1_728_414_793)
    end
  end
end

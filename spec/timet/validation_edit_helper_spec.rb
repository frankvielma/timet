# frozen_string_literal: true

require 'rspec'

RSpec.describe Timet::ValidationEditHelper do
  subject(:validation_helper) do
    klass = Class.new do
      include Timet::ValidationEditHelper

      attr_reader :db

      def initialize(db)
        @db = db
      end
    end
    klass.new(db)
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
      allow(validation_helper).to receive(:print_error)
    end

    context 'when new_value is nil' do
      it 'returns nil' do
        expect(validation_helper.validate_and_update(item, field_data[:field], nil)).to be_nil
      end
    end

    context 'when field is a time field' do
      it 'calls process_and_update_time_field' do
        allow(validation_helper).to receive(:process_and_update_time_field)
        validation_helper.validate_and_update(item, time_field_data[:time_field], time_field_data[:date_value])
        expect(validation_helper).to have_received(:process_and_update_time_field).with(item,
                                                                                        time_field_data[:time_field], time_field_data[:date_value], item[0])
      end

      context 'when date value is invalid or valid' do
        let(:time_field_data) { { time_field: 'start', date_value: 'invalid-time' } }

        it 'handles invalid date value' do
          validation_helper.validate_and_update(item, time_field_data[:time_field], time_field_data[:date_value])
          expect(validation_helper).to have_received(:print_error).with(time_field_data[:date_value])
        end

        it 'handles valid date value' do
          time_field_data[:date_value] = '2024-10-01 12:00:00'
          allow(validation_helper).to receive(:valid_time_value?).and_return(true)
          validation_helper.validate_and_update(item, time_field_data[:time_field], time_field_data[:date_value])
          expect(db).to have_received(:update_item)
        end
      end
    end

    context 'when field is not a time field' do
      it 'updates the item directly' do
        validation_helper.validate_and_update(item, field_data[:field], field_data[:new_value])
        expect(db).to have_received(:update_item).with(item[0], field_data[:field], field_data[:new_value])
      end
    end
  end

  describe '#update_time_field' do
    it 'updates the time field with the formatted date value' do
      expect(validation_helper.send(:update_time_field, item, time_field_data[:time_field], time_value)).to be_a(Time)
    end
  end
end

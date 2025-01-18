# frozen_string_literal: true

require 'rspec'

RSpec.describe Timet::ValidationEditHelper do
  subject do
    klass = Class.new do
      include Timet::ValidationEditHelper

      attr_reader :db

      def initialize(db)
        @db = db
      end
    end
    klass.new(db)
  end

  let(:db) { instance_double(Timet::Database) } # Adjust the namespace if necessary
  let(:item) { [1, 1_728_414_793, 1_728_416_293] }
  let(:field) { 'notes' }
  let(:new_value) { 'Updated notes' }
  let(:time_field) { 'start' }
  let(:date_value) { '2024-10-01 12:00:00' }
  let(:time_value) { '11:10:00' }

  before do
    allow(db).to receive(:update_item)
    allow(db).to receive(:find_item).and_return(item)
    # allow(Timet::TimeHelper).to receive_messages(format_time_string: Time.now, current_timestamp: Time.now.to_i)
    allow_any_instance_of(described_class).to receive(:print_error)
  end

  describe '#validate_and_update' do
    context 'when new_value is nil' do
      it 'returns nil' do
        expect(subject.validate_and_update(item, field, nil)).to be_nil
      end
    end

    context 'when field is a time field' do
      it 'calls process_and_update_time_field' do
        expect(subject).to receive(:process_and_update_time_field).with(item, time_field, date_value, item[0])
        subject.validate_and_update(item, time_field, date_value)
      end
    end

    context 'when field is not a time field' do
      it 'updates the item directly' do
        expect(db).to receive(:update_item).with(item[0], field, new_value)
        subject.validate_and_update(item, field, new_value)
      end
    end
  end

  describe '#process_and_update_time_field' do
    it 'formats the date value' do
      subject.send(:process_and_update_time_field, item, time_field, time_value, item[0])
    end

    context 'when date value is invalid' do
      before do
        allow(Timet::TimeHelper).to receive(:format_time_string).and_return(nil)
      end

      it 'prints an error message' do
        expect(subject).to receive(:print_error).with(time_value)
        subject.send(:process_and_update_time_field, item, time_field, time_value, item[0])
      end
    end

    context 'when date value is valid' do
      it 'updates the time field' do
        allow(subject).to receive(:valid_time_value?).and_return(true)
        expect(db).to receive(:update_item)
        subject.send(:process_and_update_time_field, item, time_field, time_value, item[0])
      end
    end
  end

  describe '#update_time_field' do
    it 'updates the time field with the formatted date value' do
      expect(subject.send(:update_time_field, item, time_field, time_value)).to be_a(Time)
    end
  end
end

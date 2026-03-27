# frozen_string_literal: true

require 'rspec'
require 'timet/validation_editor'

RSpec.describe Timet::ValidationEditor do
  subject(:editor) { described_class.new(item, db) }

  let(:db) { instance_spy(Timet::Database) }
  let(:current_date) { Time.now.strftime('%Y-%m-%d') }
  let(:item_start_time) { Time.parse("#{current_date} 10:00:00").getlocal }
  let(:item_end_time) { Time.parse("#{current_date} 11:00:00").getlocal }
  let(:item) { [1, item_start_time.to_i, item_end_time.to_i] }

  describe '#update' do
    before do
      allow(db).to receive(:update_item)
      allow(db).to receive(:find_item).and_return(nil)
    end

    context 'when field is notes' do
      it 'updates the notes field' do
        updated_item = editor.update('notes', 'New notes')
        expect(updated_item[4]).to eq('New notes')
      end
    end

    context 'when field is tag' do
      it 'updates the tag field' do
        updated_item = editor.update('tag', 'new-tag')
        expect(updated_item[3]).to eq('new-tag')
      end
    end

    context 'when field is start' do
      let(:valid_time_str) { '10:30:00' }

      it 'updates the start time' do
        original_start_time_obj = Time.at(item[1])
        new_time_components = Time.parse(valid_time_str).getlocal

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

        allow(Time).to receive(:now).and_return(Time.parse("#{current_date} 12:00:00").getlocal)

        updated_item = editor.update('start', valid_time_str)
        expect(updated_item[1]).to eq(expected_timestamp)
      end
    end

    context 'when field is invalid' do
      it 'raises ArgumentError' do
        expect { editor.update('invalid', 'value') }.to raise_error(ArgumentError, /Invalid field/)
      end
    end
  end

  describe '#update - collision detection' do
    let(:item_id) { 5 }
    let(:item_start_time) { Time.parse("#{current_date} 10:00:00").getlocal }
    let(:item_end_time) { Time.parse("#{current_date} 11:00:00").getlocal }
    let(:item) { [item_id, item_start_time.to_i, item_end_time.to_i] }

    before do
      allow(Time).to receive(:now).and_return(Time.parse("#{current_date} 12:00:00").getlocal)
    end

    context 'when new start time collides with previous item' do
      let(:prev_item_end_time) { Time.parse("#{current_date} 09:30:00").getlocal }
      let(:prev_item) { [item_id - 1, (prev_item_end_time - 3600).to_i, prev_item_end_time.to_i] }

      it 'raises ArgumentError' do
        allow(db).to receive(:find_item).with(item_id - 1).and_return(prev_item)
        allow(db).to receive(:find_item).with(item_id + 1).and_return(nil)

        colliding_time = (prev_item_end_time - 60).strftime('%H:%M:%S')
        expect { editor.update('start', "#{current_date} #{colliding_time}") }
          .to raise_error(ArgumentError, /New start time collides with previous item/)
      end
    end

    context 'when new start time collides with next item' do
      let(:next_item_start_time) { Time.parse("#{current_date} 11:30:00").getlocal }
      let(:next_item) { [item_id + 1, next_item_start_time.to_i, (next_item_start_time + 3600).to_i] }

      it 'raises ArgumentError' do
        allow(db).to receive(:find_item).with(item_id - 1).and_return(nil)
        allow(db).to receive(:find_item).with(item_id + 1).and_return(next_item)

        colliding_time = (next_item_start_time + 60).strftime('%H:%M:%S')
        expect { editor.update('start', "#{current_date} #{colliding_time}") }
          .to raise_error(ArgumentError, /New start time collides with next item/)
      end
    end

    context 'when new start time equals next item start time' do
      let(:next_item_start_time) { Time.parse("#{current_date} 11:30:00").getlocal }
      let(:next_item) { [item_id + 1, next_item_start_time.to_i, (next_item_start_time + 3600).to_i] }

      it 'raises ArgumentError' do
        allow(db).to receive(:find_item).with(item_id - 1).and_return(nil)
        allow(db).to receive(:find_item).with(item_id + 1).and_return(next_item)

        colliding_time = next_item_start_time.strftime('%Y-%m-%d %H:%M:%S')
        expect { editor.update('start', colliding_time) }
          .to raise_error(ArgumentError, /New start time collides with next item/)
      end
    end

    context 'when new start time does not collide' do
      let(:prev_item_end_time) { Time.parse("#{current_date} 09:30:00").getlocal }
      let(:prev_item) { [item_id - 1, (prev_item_end_time - 3600).to_i, prev_item_end_time.to_i] }
      let(:next_item_start_time) { Time.parse("#{current_date} 11:30:00").getlocal }
      let(:next_item) { [item_id + 1, next_item_start_time.to_i, (next_item_start_time + 3600).to_i] }

      it 'does not raise error' do
        allow(db).to receive(:find_item).with(item_id - 1).and_return(prev_item)
        allow(db).to receive(:find_item).with(item_id + 1).and_return(next_item)

        valid_time = (prev_item_end_time + 60).strftime('%H:%M:%S')
        expect { editor.update('start', "#{current_date} #{valid_time}") }.not_to raise_error
      end
    end
  end

  describe '#update - future date validation' do
    let(:item_start_time) { Time.parse("#{current_date} 10:00:00").getlocal }
    let(:item_end_time) { Time.parse("#{current_date} 11:00:00").getlocal }
    let(:item) { [1, item_start_time.to_i, item_end_time.to_i] }

    before do
      allow(db).to receive(:find_item).and_return(nil)
    end

    it 'raises ArgumentError when setting a future date' do
      stubbed_time = Time.parse("#{current_date} 12:00:00").getlocal
      future_datetime = stubbed_time + (24 * 60 * 60) + 3600
      future_datetime_str = future_datetime.strftime('%Y-%m-%d %H:%M:%S')

      allow(Time).to receive(:now).and_return(stubbed_time)
      allow(db).to receive(:update_item)

      expect { editor.update('start', future_datetime_str) }
        .to raise_error(ArgumentError, /Cannot set time to a future date/)
    end
  end
end

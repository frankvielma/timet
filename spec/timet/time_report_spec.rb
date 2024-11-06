# frozen_string_literal: true

RSpec.describe Timet::TimeReport do
  let(:db) { instance_double(Timet::Database) }
  let(:items) { [] }
  let(:options) { { filter: filter, tag: tag, csv: csv, ics: ics } }
  let(:time_report) { described_class.new(db, options) }
  let(:filter) { nil }
  let(:tag) { nil }
  let(:csv) { nil }
  let(:ics) { nil }

  before do
    allow(db).to receive_messages(all_items: items, execute_sql: [])
  end

  describe '#initialize' do
    context 'with no filter' do
      it 'sets items to all items from the database' do
        expect(time_report.items).to eq(items)
      end
    end

    context 'with a valid filter' do
      let(:filter) { 'today' }
      let(:filtered_items) { [%w[id1 start1 end1 tag1 notes1]] }

      before do
        allow(db).to receive(:execute_sql).and_return(filtered_items)
      end

      it 'sets items to filtered items' do
        expect(time_report.items).to eq(filtered_items)
      end
    end
  end

  describe '#filter_items' do
    context 'with a valid predefined filter' do
      let(:filter) { 'today' }
      let(:filtered_items) { [%w[id1 start1 end1 tag1 notes1]] }

      before do
        allow(db).to receive(:execute_sql).and_return(filtered_items)
      end

      it 'returns filtered items' do
        expect(time_report.send(:filter_items, filter, tag)).to eq(filtered_items)
      end
    end

    context 'with a valid date range filter' do
      let(:filter) { '2023-01-01..2023-01-02' }
      let(:filtered_items) { [%w[id1 start1 end1 tag1 notes1]] }

      before do
        allow(db).to receive(:execute_sql).and_return(filtered_items)
      end

      it 'returns filtered items' do
        expect(time_report.send(:filter_items, filter, tag)).to eq(filtered_items)
      end
    end

    context 'with an invalid filter' do
      let(:filter) { 'invalid_filter' }

      it 'prints an error message and returns an empty array' do
        expect do
          time_report.send(:filter_items, filter, tag)
        end.to output("Invalid filter. Supported filters: today, yesterday, week, month\n").to_stdout
        expect(time_report.send(:filter_items, filter, tag)).to eq([])
      end
    end
  end

  describe '#formatted_filter' do
    context 'with a short form filter' do
      it 'returns the full form of the filter' do
        expect(time_report.send(:formatted_filter, 't')).to eq('today')
        expect(time_report.send(:formatted_filter, 'y')).to eq('yesterday')
        expect(time_report.send(:formatted_filter, 'w')).to eq('week')
        expect(time_report.send(:formatted_filter, 'm')).to eq('month')
      end
    end

    context 'with a valid date range filter' do
      let(:filter) { '2023-01-01..2023-01-02' }

      it 'returns the filter as is' do
        expect(time_report.send(:formatted_filter, filter)).to eq(filter)
      end
    end

    context 'with an invalid filter' do
      let(:filter) { 'invalid_filter' }

      it 'returns today as the default filter' do
        expect(time_report.send(:formatted_filter, filter)).to eq('today')
      end
    end
  end

  describe '#valid_date_format?' do
    context 'with a valid single date format' do
      let(:date_string) { '2023-01-01' }

      it 'returns true' do
        expect(time_report.send(:valid_date_format?, date_string)).to be true
      end
    end

    context 'with a valid date range format' do
      let(:date_string) { '2023-01-01..2023-01-02' }

      it 'returns true' do
        expect(time_report.send(:valid_date_format?, date_string)).to be true
      end
    end

    context 'with an invalid date format' do
      let(:date_string) { 'invalid_date' }

      it 'returns false' do
        expect(time_report.send(:valid_date_format?, date_string)).to be false
      end
    end
  end

  describe '#filter_by_date_range' do
    let(:start_date) { Date.today }
    let(:end_date) { Date.today + 1 }
    let(:tag) { 'test_tag' }
    let(:filtered_items) { [%w[id1 start1 end1 tag1 notes1]] }

    before do
      allow(db).to receive(:execute_sql).and_return(filtered_items)
    end

    it 'returns filtered items' do
      expect(time_report.send(:filter_by_date_range, start_date, end_date, tag)).to eq(filtered_items)
    end
  end
end

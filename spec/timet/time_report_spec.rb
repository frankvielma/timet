# frozen_string_literal: true

RSpec.describe Timet::TimeReport do
  subject { described_class.new(db, filter) }

  let(:db) { instance_double(Timet::Database, all_items: [], execute_sql: []) }
  let(:filter) { nil }

  describe "#initialize" do
    it "calls filter_items with the filter if a filter is provided" do
      filter = "today"
      time_report = described_class.new(db, filter)
      allow(time_report).to receive(:filter_items).with(filter).and_call_original
      time_report.send(:initialize, db, filter)
      expect(time_report).to have_received(:filter_items).with(filter)
    end
  end

  describe "#display" do
    let(:time_report) { described_class.new(db, filter) }
    let(:item) { [1, 2, 3, "task"] }

    before do
      allow(time_report).to receive(:items).and_return([item])
      allow(db).to receive(:seconds_to_hms).and_return("00:00:01")
    end

    it "prints a table header" do
      expect { time_report.display }.to output(/Tracked time report:\n/).to_stdout
    end

    it "iterates over the items and prints a table row for each" do
      expect { time_report.display }.to output(/#{item[0]}.*#{item[3][0..5]}/).to_stdout
    end

    it "calls total" do
      expect { time_report.display }.to output(/Total:  /).to_stdout
    end
  end

  describe "#total" do
    subject(:time_report) { described_class.new(db, filter) }

    let(:first_item) { [1, 2, 3, "task"] }
    let(:second_item) { [4, 5, 6, "task"] }

    before do
      allow(db).to receive_messages(all_items: [first_item, second_item], seconds_to_hms: "00:00:01")
    end

    it "prints the total duration" do
      expect { time_report.display }.to output(/Total:  /).to_stdout
    end
  end

  describe "#filter_items" do
    let(:time_report) { described_class.new(db, filter) }

    shared_examples "calls filter_by_date_range with the correct range" do |filter,
      expected_start_date,
      expected_end_date|
      it "calls filter_by_date_range with the correct range for '#{filter}'" do
        allow(time_report).to receive(:filter_by_date_range)
        time_report.instance_eval { filter_items(filter) }
        expect(time_report).to have_received(:filter_by_date_range).with(expected_start_date, expected_end_date)
      end
    end

    it_behaves_like "calls filter_by_date_range with the correct range", "today", Date.today, nil
    it_behaves_like "calls filter_by_date_range with the correct range", "yesterday", Date.today - 1, nil
    it_behaves_like "calls filter_by_date_range with the correct range", "week", Date.today - 7, Date.today + 1

    context "when filter is invalid" do
      it "returns an empty array" do
        filter = "invalid"
        expect(time_report.instance_eval { filter_items(filter) }).to eq([])
      end

      it "prints an error message" do
        filter = "invalid"
        allow(time_report).to receive(:puts)
        time_report.instance_eval { filter_items(filter) }
        expect(time_report).to have_received(:puts).with("Invalid filter. Supported filters: today, yesterday, week")
      end
    end
  end
end

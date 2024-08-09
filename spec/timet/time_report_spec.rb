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
    let(:item) { [1, 2, 3, "task"] }

    before do
      allow(subject).to receive(:items).and_return([item])
      allow(db).to receive(:seconds_to_hms).and_return("00:00:01")
    end

    it "prints a table header" do
      expect { subject.display }.to output(/Tracked time report:\n/).to_stdout
    end

    it "iterates over the items and prints a table row for each" do
      item = [1, 2, 3, "task"]
      allow(subject).to receive_messages(items: [item], calculate_duration: 1)
      expect do
        subject.display
      end.to output(/#{item[0]}.*#{item[3][0..5]}.*#{subject.send(:format_time,
                                                                  item[1])}.*#{subject.send(:format_time,
                                                                                            item[2]) || "-".rjust(21)}.*#{subject.send(
                                                                                              :calculate_duration, item[1], item[2]
                                                                                            )}/).to_stdout
    end

    it "calls total" do
      expect { subject.display }.to output(/Total:  /).to_stdout
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
    before do
      allow(subject).to receive(:filter_by_date_range)
    end

    it "calls filter_by_date_range with the correct range for 'today'" do
      filter = "today"
      subject.instance_eval { filter_items(filter) }
      expect(subject).to have_received(:filter_by_date_range).with(Date.today, nil)
    end

    it "calls filter_by_date_range with the correct range for 'yesterday'" do
      filter = "yesterday"
      subject.instance_eval { filter_items(filter) }
      expect(subject).to have_received(:filter_by_date_range).with(Date.today - 1, nil)
    end

    it "calls filter_by_date_range with the correct range for 'week'" do
      filter = "week"
      subject.instance_eval { filter_items(filter) }
      expect(subject).to have_received(:filter_by_date_range).with(Date.today - 7, Date.today + 1)
    end

    it "prints an error message and returns an empty array if the filter is invalid" do
      filter = "invalid"
      allow(subject).to receive(:puts)
      expect(subject.instance_eval { filter_items(filter) }).to eq([])
      expect(subject).to have_received(:puts).with("Invalid filter. Supported filters: today, yesterday, week")
    end
  end
end

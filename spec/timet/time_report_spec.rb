# frozen_string_literal: true

RSpec.describe Timet::TimeReport do
  subject { described_class.new(db, filter) }

  let(:db) { double("DB", all_items: [], execute_sql: []) }
  let(:filter) { nil }

  describe "#initialize" do
    it "calls filter_items with the filter if a filter is provided" do
      filter = "today"
      expect_any_instance_of(described_class).to receive(:filter_items).with(filter)
      described_class.new(db, filter)
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
      allow(subject).to receive(:items).and_return([item])
      allow(subject).to receive(:calculate_duration).and_return(1)
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
    let(:item1) { [1, 2, 3, "task"] }
    let(:item2) { [4, 5, 6, "task"] }

    before do
      allow(subject).to receive(:items).and_return([item1, item2])
      allow(db).to receive(:seconds_to_hms).and_return("00:00:01")
    end

    it "prints the total duration" do
      expect { subject.display }.to output(/Total:  /).to_stdout
    end
  end

  describe "#filter_items" do
    it 'calls filter_by_date with today if the filter is "today"' do
      filter = "today"
      allow(subject).to receive(:filter_by_date)
      subject.instance_eval { filter_items(filter) }
      expect(subject).to have_received(:filter_by_date).with(Date.today)
    end

    it 'calls filter_by_date with yesterday if the filter is "yesterday"' do
      filter = "yesterday"
      allow(subject).to receive(:filter_by_date)
      subject.instance_eval { filter_items(filter) }
      expect(subject).to have_received(:filter_by_date).with(Date.today - 1)
    end

    it 'calls filter_by_date with a week ago if the filter is "week"' do
      filter = "week"
      allow(subject).to receive(:filter_by_date)
      subject.instance_eval { filter_items(filter) }
      expect(subject).to have_received(:filter_by_date).with(Date.today - 7)
    end

    it "prints an error message and returns an empty array if the filter is invalid" do
      filter = "invalid"
      allow(subject).to receive(:puts)
      subject.instance_eval { filter_items(filter) }
      expect(subject).to have_received(:puts).with("Invalid filter. Supported filters: today, yesterday, week")
    end
  end

  describe "#filter_by_date" do
    it "executes a SQL query on the db with the start and end times for the date" do
      date = Date.today
      start_time = date.to_time.to_i
      end_time = (date + 1).to_time.to_i
      allow(db).to receive(:execute_sql)
      subject.instance_eval { filter_by_date(date) }
      expect(db).to have_received(:execute_sql).with("select * from items where start >= #{start_time} and start < #{end_time}")
    end
  end
end

# frozen_string_literal: true

RSpec.describe Timet::Application do
  let(:db) { instance_spy(Timet::Database) }
  let(:application) { described_class.new }

  before do
    allow(Timet::Database).to receive(:new).and_return(db)
    allow(db).to receive(:all_items).and_return([]) # Mocking the all_items method to return an array
  end

  describe "#report" do
    let(:filter) { nil }
    let(:report_instance) { instance_spy(Timet::TimeReport) }

    before do
      allow(Timet::TimeReport).to receive(:new).and_return(report_instance)
    end

    it "creates a new TimeReport instance" do
      application.report(filter)
      expect(Timet::TimeReport).to have_received(:new).with(db, filter)
    end

    it "calls display on the TimeReport instance" do
      allow(report_instance).to receive(:display) # Stub the display method
      application.report(filter)
      expect(report_instance).to have_received(:display)
    end
  end

  describe "#start" do
    let(:tag) { "test_task" }

    context "when the database is in a no_items or complete state" do
      before do
        allow(db).to receive(:insert_item)
        allow(db).to receive_messages(item_status: :no_items)
      end

      it "inserts a new item into the database" do
        application.start(tag)
        expect(db).to have_received(:insert_item)
      end

      it "outputs the correct messages" do
        allow(db).to receive(:insert_item) # To avoid unexpected call errors
        allow(application).to receive(:report)
        application.start(tag)
        expect(application).to have_received(:report)
      end
    end

    context "when the database is not in a no_items or complete state" do
      it "does not insert a new item" do
        allow(db).to receive_messages(item_status: :incomplete)

        application.start(tag)

        expect(db).not_to have_received(:insert_item)
      end

      it "prints output to stdout" do
        allow(db).to receive_messages(item_status: :incomplete)
        allow(application).to receive(:report)
        application.start(tag)
        expect(application).to have_received(:report)
      end
    end
  end

  describe "#stop" do
    let(:last_item) { [1, Time.now.to_i - 3600, nil, "test_task"] }

    context "when the database is in an incomplete state" do
      before do
        allow(db).to receive_messages(item_status: :incomplete, last_item: last_item)
      end

      it "updates the last item" do
        application.stop
        expect(db).to have_received(:update)
      end

      it "outputs the correct messages" do
        allow(db).to receive(:update) # Still needed to prevent unexpected call errors
        allow(application).to receive(:report)
        application.stop
        expect(application).to have_received(:report)
      end
    end

    context "when the database is not in an incomplete state" do
      before do
        allow(db).to receive_messages(item_status: :complete, last_item: nil)
      end

      it "does not update any item" do
        application.stop
        expect(db).not_to have_received(:update)
      end

      it "produces no output" do
        expect { application.stop }.not_to output.to_stdout
      end
    end
  end
end

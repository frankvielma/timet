# frozen_string_literal: true

RSpec.describe Timet::Application do
  let(:db) { instance_spy(Timet::Database) }
  let(:application) { described_class.new }

  before do
    allow(Timet::Database).to receive(:new).and_return(db)
  end

  describe "#start" do
    let(:tag) { "test_task" }

    context "when the database is in a no_items or complete state" do
      before do
        allow(db).to receive(:insert_item)
        allow(db).to receive_messages(item_status: :no_items, total_time: 0)
      end

      it "inserts a new item into the database" do
        application.start(tag)
        expect(db).to have_received(:insert_item)
      end

      it "starts tracking and outputs the correct messages" do
        allow(db).to receive(:insert_item) # To avoid unexpected call errors
        expect { application.start(tag) }.to output(/Tracking <#{tag}>/).to_stdout
      end
    end

    context "when the database is not in a no_items or complete state" do
      it "does not insert a new item" do
        allow(db).to receive_messages(item_status: :incomplete, total_time: 0)

        application.start(tag)

        # Assert that insert_item was not called
        expect(db).not_to have_received(:insert_item)
      end

      it "prints output to stdout" do
        allow(db).to receive_messages(item_status: :incomplete, total_time: 0)

        expect { application.start(tag) }.to output.to_stdout
      end
    end
  end

  describe "#stop" do
    let(:last_item) { [1, Time.now.to_i - 3600, Time.now.to_i, "test_task"] }

    context "when the database is in an incomplete state" do
      let(:last_item) { [1, 1_678_824_000, nil, "Test Task"] } # Example last_item

      before do
        allow(db).to receive_messages(item_status: :incomplete, last_item: last_item, total_time: 3600)
      end

      it "updates the last item" do
        application.stop
        expect(db).to have_received(:update)
      end

      it "outputs the correct messages" do
        allow(db).to receive(:update) # Still needed to prevent unexpected call errors
        expect { application.stop }.to output(/Recorded <#{last_item[3]}>/).to_stdout
      end
    end

    context "when the database is not in an incomplete state" do
      before do
        allow(db).to receive_messages(item_status: :complete, last_item: nil, total_time: 3600)
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

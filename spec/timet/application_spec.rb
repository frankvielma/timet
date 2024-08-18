# frozen_string_literal: true

RSpec.describe Timet::Application do
  let(:db) { instance_spy(Timet::Database) }
  let(:application) { described_class.new }
  let(:item) { { id: 1, start_time: Time.now, end_time: Time.now } }
  let(:time_report) { instance_double(Timet::TimeReport) }

  before do
    allow(Timet::Database).to receive(:new).and_return(db)
    allow(db).to receive(:all_items).and_return([])
  end

  describe "#report" do
    let(:report_params) { { filter: nil, tag: nil } }

    before do
      allow(Timet::TimeReport).to receive(:new).and_return(time_report)
    end

    it "creates a new TimeReport instance" do
      application.report(report_params[:filter], report_params[:tag])
      expect(Timet::TimeReport).to have_received(:new).with(db, report_params[:filter], report_params[:tag])
    end

    it "calls display on the TimeReport instance" do
      allow(time_report).to receive(:display)
      application.report(report_params[:filter])
      expect(time_report).to have_received(:display)
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
        allow(db).to receive(:insert_item)
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
        allow(db).to receive(:update)
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

  describe "#resume" do
    context "when a task is currently being tracked" do
      before do
        allow(db).to receive(:item_status).and_return(:incomplete)
      end

      it "prints a message indicating a task is being tracked" do
        expect { application.resume }.to output("A task is currently being tracked.\n").to_stdout
      end
    end

    context "when no task is being tracked" do
      before do
        allow(db).to receive(:item_status).and_return(:complete)
      end

      it "starts the last task if there is one" do
        allow(db).to receive(:last_item).and_return(["task_name"])
        allow(application).to receive(:start)
        application.resume
        expect(application).to have_received(:start).with("task_name")
      end

      it "does not call start if there is no last task" do
        allow(db).to receive(:last_item).and_return(nil)
        allow(application).to receive(:start)
        application.resume
        expect(application).not_to have_received(:start)
      end
    end
  end

  describe "#delete" do
    context "when item exists" do
      before do
        allow(db).to receive(:find_item).with(1).and_return(item)
        allow(Timet::TimeReport).to receive(:new).and_return(time_report)
        allow(time_report).to receive(:row)
        allow(db).to receive(:delete_item)
      end

      let(:prompt) { instance_double(TTY::Prompt) }

      it "finds the item by id" do
        allow(TTY::Prompt).to receive(:new).and_return(prompt)
        allow(prompt).to receive(:yes?).and_return(true)
        application.delete(1)
        expect(db).to have_received(:find_item).with(1)
      end

      it "shows a report for the item" do
        allow(TTY::Prompt).to receive(:new).and_return(prompt)
        allow(prompt).to receive(:yes?).and_return(true)
        application.delete(1)
        expect(time_report).to have_received(:row).with(item)
      end

      it "outputs 'Deleted 1' when the user confirms deletion" do
        allow(TTY::Prompt).to receive(:new).and_return(prompt)
        allow(prompt).to receive(:yes?).and_return(true)
        expect { application.delete(1) }.to output("Deleted 1\n").to_stdout
      end

      it "deletes the item when the user confirms deletion" do
        allow(TTY::Prompt).to receive(:new).and_return(prompt)
        allow(prompt).to receive(:yes?).and_return(true)
        application.delete(1)
        expect(db).to have_received(:delete_item).with(1)
      end

      it "does not delete if the user cancels" do
        allow(TTY::Prompt).to receive(:new).and_return(prompt)
        allow(prompt).to receive(:yes?).and_return(false)
        application.delete(1)
        expect(db).not_to have_received(:delete_item)
      end
    end

    context "when item does not exist" do
      before do
        allow(db).to receive(:find_item).with(1).and_return(nil)
      end

      it "outputs a message indicating the item was not found" do
        expect { application.delete(1) }.to output("No tracked time found for id: 1\n").to_stdout
      end

      it "does not attempt to delete the item" do
        application.delete(1)
        expect(db).not_to have_received(:delete_item)
      end
    end
  end
end

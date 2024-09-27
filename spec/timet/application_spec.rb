# frozen_string_literal: true

RSpec.describe Timet::Application do
  let(:db) { instance_double(Timet::Database) }
  let(:app) { described_class.new }
  let(:time_report) { instance_double(Timet::TimeReport) }

  before do
    allow(Timet::Database).to receive(:new).and_return(db)
    allow(db).to receive(:insert_item)
    allow(db).to receive(:update)
    allow(db).to receive(:last_item)
    allow(db).to receive(:last_item_status)
    allow(db).to receive(:find_item)
    allow(db).to receive(:fetch_last_id)
    allow(db).to receive(:delete_item)
    allow(db).to receive(:update_item)
    allow(db).to receive(:all_items)

    allow(Timet::TimeReport).to receive(:new).and_return(time_report)
    allow(time_report).to receive(:display)
    allow(time_report).to receive(:export_sheet)
    allow(time_report).to receive(:show_row)
  end

  describe '#start' do
    before do
      allow(app).to receive(:summary)
    end

    it 'inserts a new item when there are no items or last item is complete' do
      allow(db).to receive(:last_item_status).and_return(:no_items)
      app.start('test_tag', 'test_notes')
      expect(db).to have_received(:insert_item)
    end

    it 'does not insert a new item when last item is incomplete' do
      allow(db).to receive(:last_item_status).and_return(:incomplete)
      app.start('test_tag', 'test_notes')
      expect(db).not_to have_received(:insert_item)
    end
  end

  describe '#stop' do
    before do
      allow(app).to receive(:summary)
    end

    it 'updates the last item when it is incomplete' do
      allow(db).to receive(:last_item_status).and_return(:incomplete)
      app.stop
      expect(db).to have_received(:update)
    end

    it 'does not update when last item is complete' do
      allow(db).to receive(:last_item_status).and_return(:complete)
      app.stop
      expect(db).not_to have_received(:update)
    end
  end

  describe '#resume' do
    before do
      allow(app).to receive(:summary)
      allow(app).to receive(:start)
    end

    it 'starts a new task with last item details when last item is complete' do
      allow(db).to receive_messages(last_item_status: :complete, last_item: [nil, nil, nil, 'last_tag', 'last_notes'])
      app.resume
      expect(app).to have_received(:start).with('last_tag', 'last_notes')
    end

    it 'does not start a new task when a task is currently being tracked' do
      allow(db).to receive(:last_item_status).and_return(:incomplete)
      expect { app.resume }.to output("A task is currently being tracked.\n").to_stdout
      expect(app).not_to have_received(:start)
    end
  end

  describe '#summary' do
    it 'displays the summary' do
      app.summary
      expect(time_report).to have_received(:display)
    end

    it 'exports to CSV when filename is provided' do
      app.options = { csv: 'test.csv' }
      app.summary
      expect(time_report).to have_received(:export_sheet)
    end
  end

  describe '#edit' do
    let(:item) { [1, 1_600_000_000, 1_600_003_600, 'test_tag', 'test_notes'] }
    let(:prompt) { instance_double(TTY::Prompt) }

    before do
      allow(TTY::Prompt).to receive(:new).and_return(prompt)
      allow(prompt).to receive_messages(select: 'Notes', ask: 'new_notes')
      allow(app).to receive(:summary)
    end

    context 'when item is found' do
      before do
        allow(db).to receive(:find_item).and_return(item)
      end

      it 'updates the item with new value' do
        app.edit('1')
        expect(db).to have_received(:update_item).with(1, 'notes', 'new_notes')
      end
    end

    context 'when item is not found' do
      before do
        allow(db).to receive(:find_item).and_return(nil)
      end

      it 'displays error message when item is not found' do
        expect { app.edit('999') }.to output("No tracked time found for id: 999\n").to_stdout
      end
    end
  end

  describe '#delete' do
    let(:item) { [1, 1_600_000_000, 1_600_003_600, 'test_tag', 'test_notes'] }
    let(:prompt) { instance_double(TTY::Prompt) }

    before do
      allow(TTY::Prompt).to receive(:new).and_return(prompt)
      allow(prompt).to receive(:yes?).and_return(true)
      allow(db).to receive(:find_item).and_return(item)
    end

    it 'deletes the item when confirmed' do
      expect { app.delete('1') }.to output("Deleted 1\n").to_stdout
      expect(db).to have_received(:delete_item).with('1')
    end

    it 'does not delete the item when not confirmed' do
      allow(prompt).to receive(:yes?).and_return(false)
      app.delete('1')
      expect(db).not_to have_received(:delete_item)
    end
  end

  describe '#cancel' do
    it 'cancels active time tracking' do
      allow(db).to receive_messages(last_item_status: :incomplete, fetch_last_id: '1')
      expect { app.cancel }.to output("Canceled active time tracking 1\n").to_stdout
      expect(db).to have_received(:delete_item).with('1')
    end

    it 'displays message when no active time tracking' do
      allow(db).to receive(:last_item_status).and_return(:complete)
      expect { app.cancel }.to output("There is no active time tracking\n").to_stdout
    end
  end
end

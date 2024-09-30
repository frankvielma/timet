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
    allow(time_report).to receive(:items).and_return(['item'])
  end

  describe '#start' do
    context 'when the database is empty or the most recent item is finished' do
      before do
        allow(db).to receive(:last_item_status).and_return(:no_items)
      end

      it 'inserts a new item into the database' do
        app.start('tag', 'my notes...')
        expect(db).to have_received(:insert_item).with(Time.now.utc.to_i, 'tag', 'my notes...')
      end

      it 'calls summary after inserting the item' do
        allow(app).to receive(:summary)
        app.start('tag', 'my notes...')
        expect(app).to have_received(:summary)
      end
    end

    context 'when the last item is still in progress' do
      before do
        allow(db).to receive(:last_item_status).and_return(:in_progress)
      end

      it 'does not insert a new item into the database' do
        app.start('tag', 'my notes...')
        expect(db).not_to have_received(:insert_item)
      end

      it 'calls summary' do
        allow(app).to receive(:summary)
        app.start('tag', 'my notes...')
        expect(app).to have_received(:summary)
      end
    end

    context 'when notes are provided via --notes option' do
      before do
        allow(db).to receive(:last_item_status).and_return(:no_items)
        allow(app).to receive(:options).and_return({ notes: 'my notes from option' })
        allow(Time).to receive(:now).and_return(Time.at(1_700_000_000))
      end

      it 'inserts a new item into the database with the provided notes from options' do
        app.start('tag')

        expect(db).to have_received(:insert_item).with(1_700_000_000, 'tag', 'my notes from option')
      end
    end
  end

  describe '#stop' do
    context 'when the last item is in progress' do
      before do
        start_time = Time.now.utc.to_i - 3600
        allow(db).to receive_messages(last_item_status: :in_progress,
                                      last_item: { 'start' => start_time,
                                                   'stop' => nil })
      end

      it 'updates the last item with the stop time' do
        app.stop
        expect(db).to have_received(:update).with(Time.now.utc.to_i)
      end

      it 'calls summary' do
        allow(app).to receive(:summary)
        app.stop
        expect(app).to have_received(:summary)
      end
    end

    context 'when the last item is complete' do
      before do
        allow(db).to receive_messages(last_item_status: :complete)
      end

      it 'does not update the database' do
        app.stop
        expect(db).not_to have_received(:update)
      end

      it 'returns nil' do
        expect(app.stop).to be_nil
      end
    end
  end

  describe '#resume' do
    context 'when a task is currently being tracked' do
      let(:status) { :in_progress }

      it 'prints a message indicating that a task is being tracked' do
        allow(db).to receive(:last_item_status).and_return(status)
        expect { app.resume }.to output(/A task is currently being tracked./).to_stdout
      end

      it 'does not call start' do
        allow(app).to receive(:start)
        app.resume

        expect(app).not_to have_received(:start)
      end
    end

    context 'when there is a last task' do
      let(:last_item) { ['task', '2024-01-01', '12:00', 'tag', 'notes'] }
      let(:last_item_status) { :complete }

      before do
        allow(db).to receive_messages(
          last_item_status: last_item_status,
          last_item: last_item
        )
      end

      it 'retrieves the last item status from the database' do
        app.resume
        expect(db).to have_received(:last_item_status).twice
      end

      it 'retrieves the last item from the database' do
        app.resume
        expect(db).to have_received(:last_item)
      end

      it 'calls start with the tag and notes' do
        allow(app).to receive(:start)
        app.resume
        expect(app).to have_received(:start).with('tag', 'notes')
      end
    end

    context 'when there are no items' do
      let(:status) { :no_items }

      before do
        allow(db).to receive_messages(last_item_status: status, last_item: nil)
      end

      it 'retrieves the last item status from the database' do
        app.resume
        expect(db).to have_received(:last_item_status)
      end

      it 'does not retrieve the last item from the database' do
        app.resume
        expect(db).not_to have_received(:last_item)
      end

      it 'does not call start' do
        allow(app).to receive(:start)
        app.resume
        expect(app).not_to have_received(:start)
      end
    end
  end

  describe '#summary' do
    context 'when no arguments are passed' do
      it 'displays a summary of today' do
        app.summary
        expect(time_report).to have_received(:display)
      end
    end

    context 'when a filter is passed' do
      it 'displays a summary for the given filter' do
        app.summary('week')
        expect(time_report).to have_received(:display)
      end
    end

    context 'when a tag is passed' do
      it 'displays a summary for the given tag' do
        app.summary(nil, 'work')
        expect(time_report).to have_received(:display)
      end
    end

    context 'when a csv filename is passed' do
      before do
        allow(time_report).to receive(:items).and_return(['item'])
      end

      it 'displays the summary' do
        app.options = { csv: 'output.csv' }
        app.summary
        expect(time_report).to have_received(:display)
      end

      it 'exports the summary to the given csv filename' do
        app.options = { csv: 'output.csv' }
        app.summary
        expect(time_report).to have_received(:export_sheet)
      end
    end

    context 'when no items are found' do
      before do
        allow(time_report).to receive(:items).and_return([])
      end

      it 'prints a message indicating no items to export' do
        app.options = { csv: 'output.csv' }
        expect { app.summary }.to output("No items found to export\n").to_stdout
      end
    end

    context 'when both filter and tag are passed' do
      it 'displays a summary for the given filter and tag' do
        app.summary('month', 'personal')
        expect(time_report).to have_received(:display)
      end
    end
  end

  describe '#edit' do
    let(:item) { [1, 1_700_000_000, 1_700_003_600, 'test_tag', 'test_notes'] }
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
    let(:item) { [1, 1_700_000_000, 1_700_003_600, 'test_tag', 'test_notes'] }
    let(:prompt) { instance_double(TTY::Prompt) }

    before do
      allow(TTY::Prompt).to receive(:new).and_return(prompt)
      allow(prompt).to receive(:yes?).and_return(true)
      allow(db).to receive(:find_item).and_return(item)
    end

    it 'deletes the item' do
      app.delete('1')
      expect(db).to have_received(:delete_item).with('1')
    end

    it 'outputs a confirmation message' do
      allow(db).to receive(:delete_item)
      expect { app.delete('1') }.to output("Deleted 1\n").to_stdout
    end

    it 'does not delete the item when not confirmed' do
      allow(prompt).to receive(:yes?).and_return(false)
      app.delete('1')
      expect(db).not_to have_received(:delete_item)
    end
  end

  describe '#cancel' do
    it 'cancels active time tracking and outputs message' do
      allow(db).to receive_messages(last_item_status: :in_progress, fetch_last_id: '1')
      expect { app.cancel }.to output("Canceled active time tracking 1\n").to_stdout
    end

    it 'deletes the last item from the database' do
      allow(db).to receive_messages(last_item_status: :in_progress, fetch_last_id: '1')
      app.cancel
      expect(db).to have_received(:delete_item).with('1')
    end

    it 'displays message when no active time tracking' do
      allow(db).to receive(:last_item_status).and_return(:complete)
      expect { app.cancel }.to output("There is no active time tracking\n").to_stdout
    end
  end
end

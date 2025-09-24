# frozen_string_literal: true

require 'timet/application_helper'

RSpec.describe Timet::ApplicationHelper do
  include described_class

  describe '#show_message' do
    it 'returns the correct message for a given tag' do
      tag = 'work'
      expected_message = 'Pomodoro session complete (work). Time for a break.'
      expect(show_message(tag)).to eq(expected_message)
    end
  end

  describe '#export_report' do
    let(:report) { instance_double(Timet::TimeReport, items: items) }
    let(:options) { {} }
    let(:report_exporter) { class_spy(Timet::ApplicationHelper::ReportExporter) }

    before do
      stub_const('Timet::ApplicationHelper::ReportExporter', report_exporter)
    end

    context 'when there are items in the report' do
      let(:items) { [1, 2, 3] }

      it 'calls export_csv_report and export_icalendar_report' do
        export_report(report, options)
        expect(report_exporter).to have_received(:export_csv_report).with(report, options)
        export_report(report, options)
      end
    end

    context 'when there are no items in the report' do
      let(:items) { [] }

      it 'prints "No items found to export"' do
        expect { export_report(report, options) }.to output("No items found to export\n").to_stdout
      end
    end
  end

  describe '#run_linux_session' do
    let(:time) { 1500 }
    let(:tag) { 'work' }
    let(:mock_pid) { 1234 }

    before do
      # To avoid the warning with the SQLite3 database connection
      @db = instance_double(Timet::Database)
      allow(@db).to receive(:close)

      allow(self).to receive(:fork).and_yield.and_return(mock_pid)
      allow(self).to receive(:sleep)
      allow(self).to receive(:system)
      allow(Process).to receive(:detach)
    end

    it 'spawns the correct commands' do
      run_linux_session(time, tag)
      expect(self).to have_received(:sleep).with(time)
      expect(self).to have_received(:system).with('tput', 'bel')
      expect(self).to have_received(:system).with('tt', 'stop')
      expect(self).to have_received(:system).with('notify-send', '--icon=clock', show_message(tag))
    end

    it 'detaches the process' do
      run_linux_session(time, tag)
      expect(Process).to have_received(:detach).with(mock_pid)
    end
  end

  describe '#run_mac_session' do
    let(:time) { 1500 }
    let(:tag) { 'work' }
    let(:mock_pid) { 1235 }

    before do
      # To avoid the warning with the SQLite3 database connection
      @db = instance_double(Timet::Database)
      allow(@db).to receive(:close)

      allow(self).to receive(:fork).and_yield.and_return(mock_pid)
      allow(self).to receive(:sleep)
      allow(self).to receive(:system)
      allow(Process).to receive(:detach)
    end

    it 'spawns the correct commands' do
      run_mac_session(time, tag)
      expect(self).to have_received(:sleep).with(time)
      expect(self).to have_received(:system).with('afplay', '/System/Library/Sounds/Basso.aiff')
      expect(self).to have_received(:system).with('tt', 'stop')
      message = show_message(tag)
      escaped_message = message.gsub('\\', '\\\\').gsub('"', '\"')
      applescript_command = "display notification \"#{escaped_message}\""
      expect(self).to have_received(:system).with('osascript', '-e', applescript_command)
    end

    it 'detaches the process' do
      run_mac_session(time, tag)
      expect(Process).to have_received(:detach).with(mock_pid)
    end
  end
end

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
    let(:expected_command) do
      "sleep #{time} && tput bel && tt stop 0 && notify-send --icon=clock " \
        "'Pomodoro session complete (#{tag}). Time for a break.' &"
    end
    let(:mock_pid) { 1234 }

    before do
      allow(Kernel).to receive(:spawn).and_return(mock_pid)
      allow(Process).to receive(:detach)
    end

    it 'spawns the correct command' do
      run_linux_session(time, tag)
      expect(Kernel).to have_received(:spawn).with(expected_command).once
    end

    it 'detaches the process' do
      run_linux_session(time, tag)
      expect(Process).to have_received(:detach).with(mock_pid).once
    end
  end

  describe '#run_mac_session' do
    let(:time) { 1500 }
    let(:tag) { 'work' }
    let(:expected_command) do
      "sleep #{time} && afplay /System/Library/Sounds/Basso.aiff && tt stop 0 && " \
        "osascript -e 'display notification \"Pomodoro session complete (#{tag}). Time for a break.\"' &"
    end
    let(:mock_pid) { 1235 }

    before do
      allow(Kernel).to receive(:spawn).and_return(mock_pid)
      allow(Process).to receive(:detach)
    end

    it 'spawns the correct command' do
      run_mac_session(time, tag)
      expect(Kernel).to have_received(:spawn).with(expected_command).once
    end

    it 'detaches the process' do
      run_mac_session(time, tag)
      expect(Process).to have_received(:detach).with(mock_pid).once
    end
  end
end

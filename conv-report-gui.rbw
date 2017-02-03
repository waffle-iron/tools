#!/usr/bin/ruby

require 'tk'
require_relative 'conv-report'

Encoding.default_external = Encoding::UTF_8

#Tk::Tile.set_theme :xpnative

class ConverterGui

  def convert(yamlfile, month = nil)
    data = ReportData.load_yaml_file(yamlfile)
    data.extract_by_month(month || Time.now.month)
                  .fill_all_tasks_hours.table_each do |vals|
      date, hours, tasks, stime, etime = *vals
      key = date.to_s
      tasks.split(/\n/).each.with_index do |task, i|
        if i == 0
          @tree.insert nil, :end, id: key, text: key,
                       value: [hours, stime, etime]
          @tree.itemconfigure(key, :open, true) if key == "#{Time.now.month}/#{Time.now.day}"
        end
        @tree.insert key, :end, id: "#{key}-#{i}", text: '',
                     value: [task, '', '']
      end
    end
  end

  YAML_FILE = "report.yaml"

  COLS = %w(workhour start end)
  NAMES = %w(作業時間 開始 終了)
  WIDTHS = [300, 60, 60]

  def main
    @root = TkRoot.new
    @root.title = "Report Converter"

    yamlfile = YAML_FILE

    @clock_label = Tk::Label.new(@root)
    @clock_label.text = yamlfile
    @clock_label.pack
    
    @mon = TkVariable.new(Time.now.month.to_s)
    @mon_entry = Tk::Entry.new
    @mon_entry.textvariable @mon
    @mon_entry.pack

    @button = TkButton.new(@root)
    @button.text = 'convert'
    @button.command = proc {convert yamlfile, @mon.value.to_i}
    @button.pack

    @tree = Ttk::Treeview.new.pack(expand: true, fill: :both)
    @tree.columns = COLS.join(' ')
    COLS.zip(NAMES, WIDTHS).each do |col, name, width|
      @tree.heading_configure col, text: name
      @tree.column_configure col, width: width
    end

    Tk.mainloop

  end
end

ConverterGui.new.main

# vim:set ft=ruby ts=2 sw=2 et:

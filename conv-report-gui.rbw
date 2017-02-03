#!/usr/bin/ruby

require 'tk'
require_relative 'conv-report'

Encoding.default_external = Encoding::UTF_8

#Tk::Tile.set_theme :xpnative

class ConverterGui

  def clear
    ids = @tree.children('').map{|c| c.id}
    @tree.delete ids
  end

  def convert(yamlfile, month = nil)
    clear
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

  def select_file
    Tk.getOpenFile filetypes: [
        ["yaml", ".yaml"],
        ["all", ".*"]],
      "defaultextension" => ".yaml"
  end

  YAML_FILE = "report.yaml"

  COLS = %w(workhour start end)
  NAMES = %w(作業時間 開始 終了)
  WIDTHS = [300, 60, 60]

  def main
    @root = TkRoot.new
    @root.title = "Report Converter"

    @yamlfile = File.join(Dir.pwd, YAML_FILE)

    file_frame = Tk::Frame.new(@root)
    label = Tk::Label.new(file_frame)
    label.pack side: :left
    label.text "File: " + @yamlfile
    btn = TkButton.new(file_frame) do 
      text 'Choose'
      pack side: :left
    end
    btn.command = proc do
      f = select_file
      @yamlfile = f if f
    end
    file_frame.pack anchor: :w

    month_frame = Tk::Frame.new(@root)
    
    Tk::Label.new(month_frame) do
      text "Month"
      pack side: :left
    end
    
    @mon = TkVariable.new(Time.now.month.to_s)
    ent = Tk::Entry.new(month_frame) do 
      pack side: :left
    end
    ent.textvariable @mon

    btn = TkButton.new(month_frame) do
      text 'Load'
      pack side: :left
    end
    btn.command proc {convert @yamlfile, @mon.value.to_i}

    month_frame.pack anchor: :w

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

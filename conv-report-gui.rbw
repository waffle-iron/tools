#!/usr/bin/ruby

require 'date'
require 'tk'
require_relative 'conv-report'

Encoding.default_external = Encoding::UTF_8

class ConverterGui

  def clear_table
    ids = @tree.children('').map{|c| c.id}
    @tree.delete ids
  end

  def load_yaml(yamlfile, month = nil)
    clear_table
    today = Time.now
    prevday = (1..6).each do |d|
      pd = (Date.today - d).to_time
      break pd if (1..5).include?(pd.wday)
    end
    # 昨日と今日の作業詳細はデフォルトで開いておく
    openkeys = [prevday, today].map{|d| "#{d.month}/#{d.day}"}

    data = ReportData.load_yaml_file(yamlfile)
    data = data.extract_by_month(month || Time.now.month)
    data.fill_all_tasks_hours.table_each do |vals|
      date, hours, tasks, stime, etime = *vals
      hours ||= 'N/A'
      key = date.to_s
      keytext = Time.parse(date).strftime("%m/%d (%a)")
      tasks.split(/\n/).each.with_index do |task, i|
        if i == 0
          @tree.insert nil, :end, id: key, text: keytext,
                       value: [hours, stime, etime]
          @tree.itemconfigure(key, :open, true) if openkeys.include?(key)
        end
        @tree.insert key, :end, id: "#{key}-#{i}", text: '',
                     value: [task, '', '']
      end
    end

    # monthly sum
    @tree.insert nil, :end, id: :total, text: "合計",
      value: [data.sum_hours.round(2), '', '']
  end

  def convert(yamlfile, csvfile, month)
    ReportConverter.convert_to_csv yamlfile, csvfile, month: month
  end

  def select_file
    Tk.getOpenFile filetypes: [
        ["yaml", ".yaml"],
        ["all", ".*"]],
      "defaultextension" => ".yaml"
  end

  YAML_FILE = "report.yaml"
  CSV_FILE = "report_out.csv"

  COLS = %w(#0 workhour start end)
  NAMES = %w(月日 作業時間 開始 終了)
  WIDTHS = [120, 300, 60, 60]

  def main
    @root = TkRoot.new
    @root.title = "Report Converter"

    @yamlfile = File.join(Dir.pwd, YAML_FILE)

    # FILE FRAME
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
    file_frame.pack anchor: :w, pady: 2

    # MONTH FRAME
    month_frame = Tk::Frame.new(@root)
    
    Tk::Label.new(month_frame) do
      text "Month: "
      pack side: :left
    end

    @mon = TkVariable.new(Time.now.month.to_s)
    ent = Tk::Entry.new(month_frame) do 
      width 4
      pack side: :left
    end
    ent.textvariable @mon

    btn = TkButton.new(month_frame) do 
      text "▼"
      pack side: :left
    end
    btn.command do
      @mon.value = @mon.value.to_i - 1
      load_yaml @yamlfile, @mon.value.to_i
    end
    
    btn = TkButton.new(month_frame) do 
      text "▲"
      pack side: :left
    end
    btn.command do
      @mon.value = @mon.value.to_i + 1
      load_yaml @yamlfile, @mon.value.to_i
    end

    btn = TkButton.new(month_frame) do
      text 'Load'
      pack side: :left, padx: 20
    end
    btn.command do
      load_yaml @yamlfile, @mon.value.to_i
    end

    month_frame.pack anchor: :w, pady: 2

    # COMMAND FRAME
    command_frame = Tk::Frame.new(@root)

    Tk::Label.new(command_frame) do
      pack side: :left
      text "Convert: "
    end

    btn = TkButton.new(command_frame) do
      text 'to CSV'
      pack side: :left
    end
    btn.command do
      convert @yamlfile, CSV_FILE, @mon.value.to_i
      ans = Tk.messageBox(type: :yesno, title: "Convert to CSV",
        message: "Conversion completed.\nOpen CSV file?")
      if ans == "yes"
        # Open csv with excel on windows
        system "start #{CSV_FILE}" if ENV['OS'] == 'Windows_NT'
      end
    end

    btn = TkButton.new(command_frame) do
      text 'to RJB'
      pack side: :left
    end
    btn.command do
      data = ReportData.load_yaml_file(@yamlfile)
      data = data.extract_by_month(@mon.value.to_i || Time.now.month)
      data.table_each do |vals|
        date, hours, tasks, stime, etime = *vals
        puts [date, stime, etime].join(",").gsub(/:/, ',')
      end
    end

    command_frame.pack anchor: :w, pady: 2

    # DATA TREE VIEW
    treeframe = Tk::Frame.new(@root)
    scbar = TkYScrollbar.new(treeframe)
    scbar.pack side: :right, fill: :both

    @tree = Ttk::Treeview.new(treeframe, yscrollcommand: proc{|*args| scbar.set(*args)})
    @tree.pack(expand: true, fill: :both)
    @tree.columns = COLS[1..-1].join(' ')
    COLS.zip(NAMES, WIDTHS).each do |col, name, width|
      @tree.heading_configure col, text: name
      @tree.column_configure col, width: width
    end
    scbar.command do |*args|
      @tree.yview(*args)
    end

    treeframe.pack expand: true, fill: :both

    Tk.mainloop

  end
end

ConverterGui.new.main

# vim:set ft=ruby ts=2 sw=2 et:

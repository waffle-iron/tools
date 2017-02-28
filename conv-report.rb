#!/usr/bin/ruby
#
# YAML で作った作業報告書を Excel に貼り付けられる CSV 形式で
# 出力するツール。
#
# YAML書式
# mm/dd:
#   timecard: hh:mm-hh:mm
#   tasks:
#     - task1 (0.5h)
#     - task2 (1.25h)
#        :

require 'yaml'
require 'time'

module ReportData
  LUNCH_SECS = 3600 # 昼休み時間(秒)
  ROUND_UNIT = nil # 15 * 60 # 丸め単位 nil だと丸めない

  class DayData
    attr_accessor :date, :stime, :etime, :hours, :tasks

    def parse(yaml)
      @stime = @etime = ""
      @stime, @etime = yaml["timecard"].split(/-/) if yaml["timecard"]
      @hours = calc_hours(stime, etime)
      @tasks = yaml["tasks"]
      self
    end
  
    def calc_hours(stime, etime)
      return nil unless /\d?\d:\d?\d/ =~ stime && /\d?\d:\d?\d/ =~ etime
    
      # Substruction of Times gives float secs
      elapsed = Time.parse(etime) - Time.parse(stime)
      elapsed -= LUNCH_SECS if Time.parse(stime) < Time.parse("12:30")
      elapsed = (elapsed / ROUND_UNIT).round * ROUND_UNIT if ROUND_UNIT
      elapsed / 3600.0
    end

    def self.from_yaml(yaml)
      new.parse yaml
    end
  end

  def fill_all_tasks_hours
    each do |date, vals|
      if vals
        fill_task_hours vals.tasks, vals.hours
      end
    end
    self
  end

  def table_each
    each do |date, vals|
      if vals
        tasks_str = ""
        tasks_str = vals.tasks.map{|s| "・#{s}"}.join("\n") if vals.tasks
        yield [date, hour_to_s(vals.hours), tasks_str] + [vals.stime, vals.etime]
      else
        yield [date, 0.0, "休日"]
      end
    end
  end

  def to_csv(opts)
    output = ""
    table_each do |vals|
      STDERR.puts vals.first if opts[:verbose]
      output << csv(vals.insert(3, *([''] * 7)))
      output << "\r\n"
    end
    output
  end
  
  def extract_by_month(month)
    result = {}
    (1..31).each do |d|
      date = Time.parse("#{month}/#{d}")
      break if date.month != month
      k = date.strftime("%-m/%-d")
      result[k] = self[k]
    end
    result.extend(ReportData)
  end

  def sum_hours
    map{|k, v| v&.hours || 0.0}.inject(:+)
  end

  module_function
  def load_yaml(yaml)
    data = {}
    yaml.each do |date, vals|
      v = DayData.from_yaml(vals)
      v.date = date
      data[date] = v
    end
    data.extend(ReportData)
  end

  def load_yaml_file(yamlfile)
    ReportData.load_yaml(YAML.load_file(yamlfile))
  end

  private

  def hour_to_s(hour)
    hour.nil? ? '' : '%4.2f' % [hour]
  end

  def fill_task_hours(tasks, hours)
    idx = nil
    assigned = 0.0
    tasks.each.with_index do |t, i|
      if /\(([\d.]+)h\)$/ =~ t
        assigned += $1.to_f
      elsif idx.nil?
        idx = i
      else
        STDERR.puts "Multiple tasks without hours detected: #{idx}, #{i}"
        return
      end
    end
    if idx && hours
      tasks[idx] += "(#{hour_to_s(hours - assigned)}h)"
    elsif hours && hours > assigned
      tasks << "UNASSIGNED!! (#{hour_to_s(hours - assigned)}h)"
    end
  end

  def csv(vals)
    vals.map{|s| %|"#{s}"| }.join(",")
  end
end

module ReportConverter
  module_function
  def convert_to_csv(yamlfile, csvfile, opts)
    data = ReportData.load_yaml_file(yamlfile)
    File.open(csvfile, "wb") do |out|
      out.print data.extract_by_month(opts[:month] || Time.now.month)
                  .fill_all_tasks_hours.to_csv(opts)
                  .encode(Encoding::CP932)
    end
  end
end


# めんどいので、ファイル名固定
YAML_FILE = "report.yaml"
CSV_FILE = "report_out.csv"

def main
  require 'optparse'
  Encoding.default_external = Encoding::UTF_8
  
  yamlfile = YAML_FILE
  csvfile = CSV_FILE
  
  opts = {}
  OptionParser.new do |op|
    op.on('-v', 'verbose mode') {opts[:verbose] = true}
    op.on('-m month', 'extract by month (default: this month)') {|v| opts[:month] = v.to_i}
    op.parse! ARGV
  end
  
  ReportConverter.convert_to_csv(yamlfile, csvfile, opts)
end

main if __FILE__ == $0

# vim:set ft=ruby ts=2 sw=2 et:

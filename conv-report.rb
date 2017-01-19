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

# めんどいので、ファイル名固定
YAML_FILE = "report.yaml"
CSV_FILE = "report_out.csv"

REST_SECS = 3600 # 休憩時間(秒)
ROUND_UNIT = nil # 15 * 60 # 丸め単位 nil だと丸めない

module ReportData

  def to_csv
    output = ""
    each do |date, vals|
      if vals
        stime = etime = ""
        stime, etime = vals["timecard"].split(/-/) if vals["timecard"]
        hours = calc_hours(stime, etime)
        tasks_str = ""
        tasks = vals["tasks"]
        if tasks
          fill_task_hours tasks, hours
          tasks_str = tasks.map{|s| "・#{s}"}.join("\n") 
        end
        
        csv_vals = [date, hour_to_s(hours), tasks_str] + [""] * 7 + [stime, etime]
      else
        csv_vals = [date, 0.0, "休日"]
      end
      output << csv(csv_vals) 
      output << "\n"
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

  module_function
  def from_yaml_file(filename)
    YAML.load_file(filename).extend(ReportData)
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
      else
        if idx
          STDERR.puts "Multiple tasks without hours detected: #{idx}, #{i}"
          return
        else
          idx = i
        end
      end
    end
    if idx && hours
      tasks[idx] += "(#{hour_to_s(hours - assigned)}h)"
    end
  end

  def csv(vals)
    vals.map{|s| %|"#{s}"| }.join(",")
  end
  
  def calc_hours(stime, etime)
    return nil unless /\d?\d:\d?\d/ =~ stime && /\d?\d:\d?\d/ =~ etime
  
    # Substruction of Times gives float secs
    elapsed = Time.parse(etime) - Time.parse(stime) - REST_SECS
    elapsed = (elapsed / ROUND_UNIT).round * ROUND_UNIT if ROUND_UNIT
    elapsed / 3600.0
  end
  
end

Encoding.default_external = Encoding::UTF_8

yamlfile = YAML_FILE
csvfile = CSV_FILE

data = ReportData.from_yaml_file(yamlfile)
File.open(csvfile, "w") do |out|
  out.print data.extract_by_month(Time.now.month).to_csv.encode(Encoding::CP932)
end

# vim:set ft=ruby ts=2 sw=2 et:

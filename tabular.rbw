#!/usr/bin/ruby

require 'csv'
require 'tk'
require_relative 'filesel'

class Tabular
  DATA = <<EOS
title, description, contents
hello, world, content
1, 2, 3
hoge, foo, haa
EOS

  def clear_table
    ids = @treeview.children('').map{|c| c.id}
    @treeview.delete ids
  end

  def load_csv(data, treeview)
    csv = CSV.new(data) #, headers: :first_row)
    rownum = 1
    first_row = true
    csv.each do |row|
      if first_row
        treeview.columns = row.join(" ")
        row.each do |col|
          col.strip!
          treeview.heading_configure col, text: col
        end
        first_row = false
        next
      end
      p row
      treeview.insert nil, :end, id: rownum, text: rownum.to_s, value: row
      rownum +=1
    end
  end


  def build_gui
    @root = TkRoot.new
    @root.title = "Tabular"

    @fileframe = FileSelector.new(@root, "csv") do
      update_view
    end
    @fileframe.pack anchor: :w, pady: 2

    treeframe = Tk::Frame.new(@root)
    scbar = TkYScrollbar.new(treeframe)
    scbar.pack side: :right, fill: :both

    @treeview = Ttk::Treeview.new(treeframe, yscrollcommand: proc{|*args| scbar.set(*args)})
    @treeview.pack expand: true, fill: :both
    @treeview.column_configure "#0", width: 50

    scbar.command do |*args|
      @treeview.yview(*args)
    end

    treeframe.pack expand: true, fill: :both
  end

  def update_view
    path = @fileframe.filepath
    if path && !path.empty?
      clear_table
      File.open(path) do |f|
        load_csv f, @treeview
      end
    end
  rescue => e
    @treeview.insert nil, :end, id: "msg", text: "Load error - #{e}"
  end

  def main
    build_gui
    update_view

    Tk.mainloop
  end
end

Encoding::default_external = Encoding::UTF_8

begin
  Tabular.new.main
rescue => e
  Tk.messageBox title: "#{File.basename($0)}: error" , message: e.to_s
end

# vim:set ts=2 sw=2 et ft=ruby:

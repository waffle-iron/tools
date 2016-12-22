require 'tk'
require 'tkafter'
require 'optparse'

class ClockApp

  DEFAULT_CONF = {
      :font    => "arial",
      :size    => 28,
      :alpha   => 1.0,
      :bg      => "white",
      :fg      => "black",
      :refresh => 1000,
      :format  => "%Y-%m-%d (%a) %H:%M:%S",
      :top     => false,
  }

  def initialize(conf = nil)
    @conf = DEFAULT_CONF.merge(conf || {})
  end

  def setup
    require 'pp'
    pp @conf
    STDOUT.flush

    @root = TkRoot.new
    @root.title = "Clock"
    @root.resizable 0, 0
    #@root.overrideredirect = true
    #@root.geometry
    @root.attributes topmost: @conf[:top],
                     alpha: @conf[:alpha]
    @root.bg = @conf[:bg]

    @clock_label = Tk::Label.new(@root)
    @clock_label.text = time_label
    @clock_label.font = TkFont.new(family: @conf[:font], size: @conf[:size])
    @clock_label.justify = :left
    @clock_label.bg = @conf[:bg]
    @clock_label.fg = @conf[:fg]
    @clock_label.pack

    @clock_label_width = nil

    @tkafter = TkAfter.new(@conf[:refresh], -1, proc {update})
  end

  def get_max_width(label)
    times = [
      Time.new(2000, 12, 28, 23, 0, 0),
      Time.new(2888, 12, 28, 23, 38, 38),
    ]
    times.map{|t| get_width(label, time_label(t))}.max
  end

  def get_width(label, sample)
    label.text = sample
    Tk.update_idletasks
    Tk.update
    label.winfo_width
  end

  def update
    unless @clock_label_width
      @clock_label_width = get_max_width(@clock_label)
      puts @clock_label_width
      @clock_label.place x: 0, y: 0, width: @clock_label_width
      Tk.update_idletasks
      Tk.update
      TkPack.propagate @root, false
    end
    @clock_label.text = time_label
  end

  def time_label(time = nil)
    (time || Time.now).strftime(@conf[:format])
  end

  def run
    @tkafter.start
    Tk.mainloop
  end
end

def parse_args(argv)
  conf = {}
  OptionParser.new do |op|
    op.on("--font=font-family")   { |v| conf[:font] = v }
    op.on("--size=font-size")     { |v| conf[:size] = v.to_i }
    op.on("--alpha=alpha")        { |v| conf[:alpha] = v.to_f }
    op.on("--format=time-format") { |v| conf[:format] = v }
    op.on("--bg=color")           { |v| conf[:bg] = v }
    op.on("--fg=color")           { |v| conf[:fg] = v }
    op.on("--top")                { conf[:top] = true }
    op.parse! argv
  end
  return conf, argv
end

conf, args = parse_args(ARGV)

app = ClockApp.new(conf)

app.setup
app.run

# vim:set ts=2 sw=2 et:


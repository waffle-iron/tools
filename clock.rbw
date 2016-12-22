require 'tk'
require 'tkafter'
require 'optparse'

class ClockApp

  DEFAULT_CONF = {
      :font => "arial",
      :size => 28,
      :alpha => 0.65,
      :bg => "white",
      :fg => "black",
      :refresh => 1000,
      :format => "%Y-%m-%d(%a) %H:%M:%S",
      :top     => false,
  }

  def initialize(conf = nil)
    @conf = DEFAULT_CONF.merge(conf || {})
  end

  def init
    require 'pp'
    pp @conf
    puts "ok"
    STDOUT.flush
    @root = TkRoot.new
    @root.title = "Clock"
    @root.resizable 0, 0
    #@root.overrideredirect = true
    #@root.geometry
    @root.attributes topmost: @conf[:top],
                     alpha: @conf[:alpha]

    @clock_label = Tk::Label.new(@root)
    @clock_label.text = time_label
    @clock_label.font = TkFont.new("-*-#{@conf[:font]}-*-r-*-#{@conf[:size]}-*")
    @clock_label.bg = @conf[:bg]
    @clock_label.fg = @conf[:fg]
    @clock_label.pack

    @tkafter = TkAfter.new(@conf[:refresh], -1, proc {update})
  end

  def update
    @clock_label.text = time_label
  end

  def time_label
    Time.now.strftime(@conf[:format])
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

app.init
app.run

# vim:set ts=2 sw=2 et:


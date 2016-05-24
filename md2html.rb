#!/usr/bin/ruby
require 'optparse'

class MhConverter

  PRE_INDENT = 4

  def initialize(output)
    @output = output
  end

  def puts(content)
    @output.puts content
  end

  def tagputs(tag, content)
    puts "<#{tag}>#{content}</#{tag}>"
  end

  def heading(level)
    spooled do |content|
      tagputs "h#{level}", content
    end
  end

  def hr
    puts "<hr/>"
  end

  def para
    spooled do |content|
      tagputs "p", content
    end
  end

  def pre
    spooled do |content|
      tagputs "pre", content
    end
  end

  def escape(s)
    s.gsub(/</, '&lt;')
     .gsub(/>/, '&gt;')
  end

  def spooled
    if @para
      yield @para
      @para = nil
    end
  end

  def set_para_mode(mode)
    debug "%s <- %s", mode, @para_mode
    @para_mode = mode
  end

  def item
    spooled do |content|
      unless @listctx.last.opened
        tag = case @listctx.last.type
              when :ul; "<ul>"
              when :ol; "<ol>"
              end
        puts "  " * (@listctx.size * 2) + tag
        @listctx.last.opened = true
      end
      puts "  " * (@listctx.size * 2 + 1) + "<li>#{content}</li>"
    end
  end

  def list
    item if @para
    return if @listctx.empty?
    last = @listctx.pop
    case last.type
    when :ul
      puts "</ul>"
    when :ol
      puts "</ol>"
    else
      STDERR.puts "Illegal list context: #{ctx}"
    end
  end

  def flush(breaktype)
    debug "flushing %s (%s)", breaktype, @para_mode
    case breaktype
    when :block
      case @para_mode
      when :pre
        pre
      when :list
        list until @listctx.empty?
      when :plain
        para
      else
        STDERR.puts "Illegal paragraph mode: #@para_mode"
      end
    when :para
      para
    when :item
      item
    when :list
      list
    end
  end

  def spool(line)
    debug "(%s)%s", @para_mode, line
    @para ||= ''
    @para << line
  end

  ListContext = Struct.new(:type, :content_indent, :opened)

  # 既存のリスト階層のどこに位置するか調べる
  def get_list_level(indent)
    @listctx.each.with_index do |ctx, i|
      if indent < ctx.content_indent
        return i
      end
    end
    nil
  end

  def current_base_indent
    if @listctx.empty?
      0
    else
      @listctx.last.content_indent
    end
  end

  def debug(format, *vals)
    STDERR.puts format % vals
  end

  def convert(input)
    set_para_mode :plain
    @blanks = 0
    @para = nil
    @listctx = []

    input.each_line do |line|

      # 空行の扱いは特別なので後段のcaseとは別に処理する。
      if /^\s*$/ =~ line
        debug ""
        @blanks += 1
        case @para_mode
        when :pre
          spool "\n"      # preブロックは空行では終わらない
        else
          if @blanks == 1
            flush :para
          elsif @blanks == 2
            flush :block
            set_para_mode :plain
          end
        end
        next
      end

      case line
      when /^==+\s*$/    # heading with underline
        if @blanks > 0
          flush :block
          spool line
        else
          heading 1
        end

      when /^--+\s*$/    # heading with underline or horizontal rule
        if @para && @blanks == 0
          heading 2
        else
          flush :block
          hr
        end

      when /^(#+)\s*(.*)/ # heading with # prefix
        flush :block
        level = $1.size
        if level <= 6
          spool $2.chomp
          heading level
        else
          spool line
        end

      when /^(( *)[-+\*] +)(.*)$/ # list
        content_indent = $1.size
        bullet_indent = $2.size
        content = $3

        flush :block if @listctx.empty?
        set_para_mode :list

        listlv = get_list_level(bullet_indent)
        debug "(%2d %4d) %4d- %d %s",
              @listctx.size, current_base_indent, content_indent, listlv || -1, content
        case listlv
        when nil
          # 新しい階層
          flush :item unless @listctx.empty?
          @listctx << ListContext.new(:ul, content_indent, false)

        when @listctx.size - 1
          # 同一階層
          flush :item
          @listctx.last.content_indent = content_indent

        else
          # リストをさかのぼる
          (listlv .. @listctx.size - 1).each do
            flush :list
          end
        end
        spool content

      when /^( *)(.*)$/   # always match
        indent = $1.size
        content = $2

        debug "(%2d %4d) %4d: %s", @listctx.size, current_base_indent, indent, content

        # 既存のリスト階層のどこに位置するか調べる
        listlv = get_list_level(indent)
        if listlv
          (listlv .. @listctx.size - 1).each do
            flush :list
          end
        end

        offset = indent - current_base_indent
        if offset >= PRE_INDENT
          flush :block if :pre != @para_mode
          set_para_mode :pre
          spool escape(" " * (offset - PRE_INDENT) + content) + "\n"
        else
          flush :block if :plain != @para_mode
          set_para_mode :plain
          spool line
        end
      end
      @blanks = 0
    end
    flush :block
  end

  def header
    puts <<-EOS.gsub(/^    /, '')
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE html>
    <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <style type="text/css">
        body { padding: 1em; }
        h1, h2, h3, h4, h5, h6 { font-weight: normal; }
        h1 { margin: 1.5em 0em; }
        h2 { border-bottom: 1px solid gray; }
        h3, h4, h5, h6 { margin-left: 30px; }
        h3 {
             border-left: 15px solid gray;
             padding-left: 5px;
        }
        pre {
          font-family: "Consolas", "Lucida Console", monospace;
          font-size: 0.9em;
          margin-left: 40px;
          padding: 0.5em;
          background-color: #F0F0F0;
        }
        body > p { margin-left: 30px; }
        p { margin-left: 10px; }
      </style>
    </head>
    <body>
    EOS
  end

  def footer
    puts <<-EOS.gsub(/^    /, '')
    </body>
    </html>
    EOS
  end

end

c = MhConverter.new(STDOUT)

c.header
c.convert ARGF
c.footer

# vim:set ts=2 sw=2 et:

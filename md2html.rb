#!/usr/bin/ruby
require 'optparse'

class MhConverter

  PRE_INDENT = 4

  HEADING_LEVEL_MAX = 6

  # 特定の行をソースから取り除くフィルター
  FILTER_REGEX = /^\s*\{\{\s*>?\s*toc\s*\}\}\s*$/

  attr_accessor :org_file

  attr_accessor :debugging

  def initialize(output)
    @output = output
    @suffix_map = {
      ".md" => ".xhtml",
    }
  end

  def debug(format, *vals)
    STDERR.puts format % vals if @debugging
  end

  def puts(content)
    @output.puts content
  end

  def print(content)
    @output.print content
  end

  def tagputs(tag, content)
    puts indent_sp + "<#{tag}>#{content}</#{tag}>"
  end

  def indent_sp
    "  " * current_context_level
  end

  def heading(level)
    spooled do |content|
      tagputs "h#{level}", content
    end
  end

  def hr
    puts "<hr/>"
  end

  def flush_paragraph
    spooled do |content|
      if current_context.paragraphed
        tagputs "p", content
      else
        print content
      end
    end
  end

  def flush_pre
    spooled do |content|
      tagputs "pre", content
    end
  end

  def flush_current
    case @para_mode
    when :pre
      flush_pre
    when :plain
      flush_paragraph
    when :blockquote
    else
      STDERR.puts "Illegal paragraph mode: #@para_mode"
    end
  end

  def escape(s)
    s.gsub(/&/, '&amp;')
     .gsub(/</, '&lt;')
     .gsub(/>/, '&gt;')
  end

  def spooled?
    @spooled_paragraph ? true : false
  end

  def clear_spool
      @spooled_paragraph = nil
  end

  def spooled
    if spooled?
      yield @spooled_paragraph.chomp
      clear_spool
    end
  end

  def set_para_mode(mode)
    debug "%s <- %s", mode, @para_mode
    @para_mode = mode
  end

  def current_context
    @contexts.last
  end

  def open_list
    tag = case current_context.type
          when :ul; "<ul>"
          when :ol; "<ol>"
          end
    puts indent_sp + tag
    current_context.status = :inlist
  end

  def open_item
    print indent_sp + " <li>"
    current_context.status = :initem
  end

  def flush_item
    if spooled?
      spooled do |content|
        debug "item : %s", content
        case current_context.status
        when :outside
          open_list
          open_item
          flush_current
        when :inlist
          open_item
          flush_current
        when :initem
          flush_current
        end
        puts "</li>"
      end
    else
      if current_context.status == :initem
        puts indent_sp + " </li>"
      end
    end
    current_context.status = :inlist
  end

  def flush_list
    flush_item
    return if current_context.type == :body
    last = @contexts.pop
    debug "LIST >>(%s)", last.type
    case last.type
    when :ul
      puts "</ul>"
    when :ol
      puts "</ol>"
    else
      STDERR.puts "Illegal context: #{ctx}"
    end
  end

  def flush(level)
    debug "flushing %s (%s)", level, @para_mode
    case level
    when :block
      open_list if current_context.status == :outside
      open_item if current_context.status == :inlist
      flush_current
      flush_list until current_context.type == :body
    when :para
      open_list if current_context.status == :outside
      open_item if current_context.status == :inlist
      flush_current
    when :item
      flush_item
    when :list
      flush_list unless current_context.type == :body
    end
    set_para_mode :plain
  end

  SCHEMES_REGEX = "http|https|ftp|mailto|file"

  # [caption](url)形式のリンクを処理したあと、裸のURLのリンク処理に
  # 引っかからないようにするために : を置き換えておく代替文字
  # 入力はHTML(XML)エスケープ済み文字列のはずなのでこの文字はありえない
  COLON_REPL = "<>"

  # process inline markups and HTML escape
  def convert_inline(line)
    line.gsub(/`([^`]*)`/) {
      # `code`
      "<code>#$1</code>"
    }.gsub(/\*\*([^*]*)\*\*/) {
      "<strong>#$1</strong>"
    }.gsub(/__([^_]*)__/) {
      "<strong>#$1</strong>"
    }.gsub(/\*([^*]*)\*/) {
      "<em>#$1</em>"
    }.gsub(/_([^_]*)_/) {
      "<em>#$1</em>"
    }.gsub(/!\[([^\]]*)\]\(([^\)]*)\)/) {
      # ![img](url)
      text = $1
      url = $2.gsub(":", COLON_REPL)
      %{<img src="#{url}" alt="#{text}" />}
    }.gsub(/\[([^\]]*)\]\(([^\)]*)\)/) {
      # [link](url)
      text = $1
      url = $2.gsub(":", COLON_REPL)
      @suffix_map.each do |from, to|
        url.gsub!(/#{from}$/, to)
      end
      %{<a href="#{url}">#{text}</a>}
    }.sub(/  +$/) {
      # force break line
      "<br/>\n"
    }.gsub(/\b(#{SCHEMES_REGEX}):\S+/) { |url|
      # bare url
      %{<a href="#{url}">#{url}</a>}
    }.gsub(COLON_REPL, ":")
  end

  def spool(line)
    debug "SPOOL(%s) %s", @para_mode, line
    @spooled_paragraph ||= ''
    line = escape(line)
    line = convert_inline(line) if @para_mode != :pre
    @spooled_paragraph << line
  end

  # 処理コンテキスト
  # type = :body, :ul, :ol
  # status = nil, :outside, :inlist, :initem
  class Context
    attr_accessor :type, :indent, :status, :paragraphed

    def initialize(type, indent, status, paragraphed)
      @type        = type
      @indent      = indent
      @status      = status
      @paragraphed = paragraphed
    end

    def to_s
      "%d %s (st:%s pa:%s)" % [@indent, @type, @status, @paragraphed]
    end
  end

  def current_context_level
    @contexts.size - 1
  end

  # インデント位置がどのレベルか調べる
  def get_context_level(indent)
    level = -1
    @contexts.each do |ctx|
      break if indent < ctx.indent
      level += 1
    end
    level
  end

  # リストのbulletの位置がどのレベルか調べる
  def bullet_context_level(bullet_indent)
    level = get_context_level(bullet_indent)
    if level == current_context_level
      nil
    else
      level + 1
    end
  end

  def push_context(type, indent)
    debug "LIST <<(%s indent:%2d)", type, indent
    @contexts << Context.new(type, indent, :outside, false)
  end

  def spool_list_item(bullet_indent, content_indent, list_type, content)
    flush :block if current_context.type == :body

    level = bullet_context_level(bullet_indent)
    debug "(lv:%2d [%s] ci:%2d - lv:%d) %s",
          current_context_level, current_context, content_indent, level || 99, content

    case level
    when nil
      # 新しい階層
      flush :item unless current_context.type == :body
      push_context list_type, content_indent
    when current_context_level
      flush :item
    else
      # リストをさかのぼる
      (current_context_level - level).times do
        flush :list
      end
    end

    # 同一階層
    if current_context.type == list_type
      current_context.indent = content_indent
    else
      flush :list
      push_context list_type, content_indent
    end

    spool content
  end

  def expand_tabs(s)
    # 行頭のタブ文字だけは空白4文字扱いする
    if /^(\t+)(.*)$/ =~ s
      s = "    " * $1.size + $2
    end
    s
  end

  def convert(input)
    clear_spool
    set_para_mode :plain
    blanks = 0
    @contexts = [Context.new(:body, 0, nil, true)]

    input.each_line do |line|

      line = expand_tabs(line)

      if /^\s*$/ =~ line
        blanks += 1
        next
      end
      last_blanks = blanks
      blanks = 0

      case line
      when FILTER_REGEX
        next
      end

      case line
      when /^==+\s*$/    # heading with underline
        if last_blanks > 0
          flush :block
          spool line
        else             #リスト内の考慮が必要
          heading 1
        end

      when /^--+\s*$/    # heading with underline or horizontal rule
        if spooled? && last_blanks == 0
          heading 2             #リスト内の考慮が必要
        else
          flush :block
          hr
        end

      when /^(#+)\s*(.*)/ # heading with # prefix
        flush :block
        level = $1.size
        if level <= HEADING_LEVEL_MAX
          spool $2.chomp
          heading level
        else
          spool line
        end

      when /^(( *)[-+\*] +)(.*)$/ # list
        flush :block if last_blanks >= 2
        spool_list_item $2.size, $1.size, :ul, $3

      when /^(( *)\d+\. +)(.*)$/ # numbered list
        flush :block if last_blanks >= 2
        spool_list_item $2.size, $1.size, :ol, $3

      when /^( *)(.*)$/   # always match
        indent = $1.size
        content = $2

        debug "(lc:%2d bi:%2d ci:%2d : ) %s",
              current_context_level, current_context.indent, indent, content

        # 既存のリスト階層のどこに位置するか調べる
        level = get_context_level(indent)

        leveldiff = current_context_level - level

        # 字下げレベルが下がっていればその分リストを閉じる。
        leveldiff.times do
          flush :list
        end

        # 空行1つ挟む場合の処理
        if leveldiff == 0 && last_blanks == 1 && @para_mode != :pre
          current_context.paragraphed = true
          flush :para
        end

        offset = indent - current_context.indent
        debug "(off:%2d lv:%2d)", offset, level

        if offset >= PRE_INDENT
          # pre
          flush :para if @para_mode != :pre

          # 空行のあとに pre ブロックが続く場合
          spool "\n" * last_blanks if last_blanks > 0 && @para_mode == :pre

          set_para_mode :pre

          spool " " * (offset - PRE_INDENT) + content + "\n"
        else
          if last_blanks > 0
            flush :para
          end
          if @para_mode == :pre
            flush :para
            set_para_mode :plain
          end
          spool line
        end
      end
    end
    debug "finishing"
    flush :block
  end

  def header
    puts <<-EOS.gsub(/^    /, '')
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE html>
    <!--
      Generated from '#{org_file}' by #{File.basename($0)} at #{Time.now}
    -->
    <html xmlns="http://www.w3.org/1999/xhtml" lang="ja" xml:lang="ja">
    <head>
      <style type="text/css">
        body { padding: 1em; }
        h1, h2, h3, h4, h5, h6 { font-weight: normal; }
        h1 {
          font-size: 250%;
          margin: 1.5em 30px; }
        h2 {
          font-size: 200%;
          margin: 1.5em 30px 0;
          border-bottom: 1px solid gray;
        }
        h3, h4, h5, h6 { margin-left: 30px; }
        h3 {
          font-size: 160%;
          border-left: 10px solid gray;
          padding-left: 5px;
        }
        h4 { font-size: 140%; font-weight: bold; }
        h5 { font-size: 120%; font-weight: bold; }
        h6 { font-size: 100%; font-style: italic;}
        pre, code {
          font-family: "Consolas", "Lucida Console", monospace;
          font-size: 0.9em;
          background-color: #F0F0F0;
        }
        pre {
          padding: 0.5em;
          overflow: auto;
          margin-left: 10px;
          border: 1px solid darkgray;
          border-radius: 6px;
        }
        body > p { margin-left: 30px; }
        body > pre { margin-left: 40px; }
        p { margin-left: 10px; }
        ul, ol { margin-left: 15px; margin-bottom: 0.6em; }
        a { text-decoration: none; }
        a:hover { text-decoration: underline; }
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

if $0 == __FILE__
  ARGF.set_encoding("UTF-8")
  c = MhConverter.new(STDOUT)
  c.org_file = ARGF.filename
  c.debugging = true
  c.header
  c.convert ARGF
  c.footer
end

# vim:set ts=2 sw=2 et:

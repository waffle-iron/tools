class FileSelector
  attr_reader :filepath, :frame
  attr_accessor :on_select

  def update_label
    @label.text "File: " + (@filepath || "")
  end

  def initialize(parent_frame, ext, default = "", &blk)
    @filepath = default
    @on_select = blk

    @frame = Tk::Frame.new(parent_frame)

    @label = Tk::Label.new(@frame)
    @label.pack side: :left
    update_label

    btn = TkButton.new(@frame) do 
      text 'Choose'
      pack side: :left
    end
    btn.command = proc do
      f = Tk.getOpenFile filetypes: [
        [ext, ".#{ext}"],
        ["all", ".*"]],
        "defaultextension" => ".#{ext}"
     if f
       @filepath = f
       update_label
       @on_select.call f if @on_select
     end
    end
    @frame
  end

  def pack(*args)
    @frame.pack *args
  end
end

# vim:set ft=ruby ts=2 sw=2 et:

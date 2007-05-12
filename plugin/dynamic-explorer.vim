"    Copyright: Copyright (C) 2007 Stephen Bach
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               dynamic-explorer.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. In no
"               event will the copyright holder be liable for any damages
"               resulting from the use of this software.
"
" Name Of File: dynamic-explorer.vim
"  Description: Dynamic Filesystem and Buffer Explorer Vim Plugin
"   Maintainer: Stephen Bach <sjbach@users.sourceforge.net>
"
" Release Date: Saturday, May 12, 2007
"      Version: 1.0.1
"               Inspired by Viewglob, Emacs, and by Jeff Lanzarotta's Buffer
"               Explorer plugin.
"
"        Usage: To launch the explorers:
"
"                 <Leader>df  - Opens the filesystem explorer.
"                 <Leader>db  - Opens the buffer explorer.
"
"               You can also use the commands:
"
"                 ":FilesystemExplorer"
"                 ":BufferExplorer"
"
"               (Personally, I map these to <Leader>f and <Leader>b)
"
"               The interface is intuitive.  When one of the explorers is
"               launched, a new window appears at bottom presenting a list of
"               files/dirs or buffers, and in the status bar is a prompt:
"
"                 > 
"
"               As you type a name, the list updates for possible matches.
"               Tab-completion works.  When you've typed enough to match an
"               entry uniquely, press <ENTER> to open it in your last used
"               window, or press <ESC> or <Ctrl-c> to cancel.
"
"               Matching is case-insensitive unless you type a capital letter
"               (similar to "smartcase" mode in Vim).
"
"               Some stuff particular to the filesystem explorer:
"                 - Hidden files are not shown unless you type the first
"                   letter in their name (which is ".").
"                 - You can recurse into and out of directories by typing the
"                   directory name and a slash, e.g. "stuff/" or "../"
"                 - <Shift-Enter> will load all files appearing in the current
"                   list.
"
"               That's pretty much the gist of it!
"
" Install Details:
" Copy this file into your $HOME/.vim/plugin directory so that it will be
" sourced on startup automatically.
"
" Note! This plugin requires Vim be compiled with Ruby interpretation.  If you
" don't know if your build of Vim has this functionality, you can check by
" running "vim --version" from the command line and looking for "+ruby".
" Alternatively, just try sourcing this script.
"
" If your version of Vim does not have "+ruby" but you would still like to
" use this plugin, you can fix it.  Here are a few tips:
"
" On Debian/Ubuntu:
"     # apt-get install vim-ruby
"
" On Gentoo:
"     # USE="ruby" emerge vim
"
" Manually:
"     - Install Ruby.
"     - Download the Vim source package.
"     # ./configure --enable-rubyinterp
"     # make && make install
"
" TODO:
" - if new_hash == previous_hash, don't bother 'repainting'.
" - order buffers by MRU.
" - buffer search looks anywhere in the name, file search looks from the
"   beginning?
" - add globbing?
"   - also add a lock key which will make the stuff that currently appears
"     listed the basis for the next match attempt.
"   - (also unlock key)
" - expand ~ to $HOME
" - filesystem highlighting for files that are in buffers?

if has("ruby")

" Commands.
if !exists(":BufferExplorer")
  command BufferExplorer :call <SID>BufferExplorerStart()
endif
if !exists(":FilesystemExplorer")
  command FilesystemExplorer :call <SID>FilesystemExplorerStart()
endif

" Default mappings.
nmap <silent> <Leader>df :FilesystemExplorer<CR>
nmap <silent> <Leader>db :BufferExplorer<CR>

" Vim-to-ruby function calls.
function! s:FilesystemExplorerStart()
  ruby $filesystem_explorer.run
endfunction

function! s:BufferExplorerStart()
  ruby $buffer_explorer.run
endfunction

function! FilesystemExplorerCancel()
  ruby $filesystem_explorer.cancel
endfunction

function! BufferExplorerCancel()
  ruby $buffer_explorer.cancel
endfunction

function! FilesystemExplorerKeyPressed(code_arg)
  ruby $filesystem_explorer.key_pressed
endfunction

function! BufferExplorerKeyPressed(code_arg)
  ruby $buffer_explorer.key_pressed
endfunction

ruby << EOF
require 'pathname'

# Simple mappings to decrease typing.
def exe(s)
  VIM.command s
end

def eva(s)
  VIM.evaluate s
end

def set(s)
  VIM.set_option s
end

def has_syntax
  eva('has("syntax")') != "0"
end

class DynamicExplorer
  private
    @@COLUMN_SEPARATOR = "    "
    @@NO_ENTRIES_STRING = "-- NO ENTRIES --" 
    @@PROMPT = "> "

  public
    def initialize
      @settings = SavedSettings.new
      @displayer = Displayer.new(title(), \
                                 @@COLUMN_SEPARATOR, \
                                 @@NO_ENTRIES_STRING)
      @input = ""
      @running = false
    end

    def run
      if !@running
        @input = ""
        @settings.save()
        @running = true
        @calling_window = $curwin
        create_explorer_window()
        refresh()
      end
    end

    def key_pressed()
      i = eva("a:code_arg").to_i

      case i
        when 32..126          # Printable characters
          c = i.chr
          add_chars(c)
        when 8                # Backspace
          del_char()
        when 9                # Tab
          tab_complete()
        when 13               # Enter
          choose()
          return
      end

      refresh()
    end

    def cancel
      cleanup() if @running
    end

  private
    def refresh
      on_refresh()
      @displayer.print(matching_entries())
      VIM.message @@PROMPT + @input
    end

    def create_explorer_window

      @displayer.create()

      # Non-special printable characters.
      printables =  '/!"#$%&\'()*+,-.0123456789:<=>?#@"' + \
                    'ABCDEFGHIJKLMNOPQRSTUVWXYZ' + \
                    '[]^_`abcdefghijklmnopqrstuvwxyz{}~'

      map_command = "noremap <silent> <buffer> "

      # Grab all input by mapping to a function call.
      printables.each_byte do |b|
        exe map_command + "<Char-#{b}> :call #{self.class}KeyPressed(#{b})<CR>"
      end

      # Special characters
      exe map_command + "<Tab>    :call #{self.class}KeyPressed(9)<CR>"
      exe map_command + "<Bslash> :call #{self.class}KeyPressed(92)<CR>"
      exe map_command + "<Space>  :call #{self.class}KeyPressed(32)<CR>"
      exe map_command + "\026|    :call #{self.class}KeyPressed(124)<CR>"
      exe map_command + "<BS>     :call #{self.class}KeyPressed(8)<CR>"

      exe map_command + "<CR>     :call #{self.class}KeyPressed(13)<CR>"
      exe map_command + "<S-CR>   :call #{self.class}KeyPressed(10)<CR>"

      exe map_command + "<Esc>    :call #{self.class}Cancel()<CR>"
      exe map_command + "<C-c>    :call #{self.class}Cancel()<CR>"

      if has_syntax()
        exe 'syntax match DynExpDir "\zs\%(\S\+ \)*\S\+\ze/" ' \
                                    'contains=DynExpSlash'
        exe 'syntax match DynExpSlash "/"'

        exe 'syntax match DynExpOneEntry "\%^\S\+\s\+\%$"'
        exe 'syntax match DynExpNoEntries "\%^\s*' \
                                          "#{@@NO_ENTRIES_STRING}" \
                                          '\s*\%$"'

        exe 'highlight link DynExpDir Directory'
        exe 'highlight link DynExpSlash Function'
        exe 'highlight link DynExpOneEntry Type'
        exe 'highlight link DynExpMatch Type'
        exe 'highlight link DynExpCurrentBuffer Constant'
        exe 'highlight link DynExpNoEntries ErrorMsg'
      end
    end

    def on_refresh
      # Blank
      exe "syntax clear DynExpMatch"
      if !input_match_string.nil?
        exe "syntax match DynExpMatch \"#{input_match_string}\""
      end
    end

    def matching_entries
      entries = all_entries()
      input_regex = pruning_regex()

      # Only return entries whose names match our input.
      pruned = Array.new
      entries.each do |x|
        if x =~ input_regex
          pruned << x
        end
      end

      return pruned
    end

    def tab_complete
      paths = matching_entries()

      return if paths.length <= 0

      start = completion_start()

      # Tab complete (yuck)
      done = false
      completion = ""
      while (!done and start + completion.length < paths[0].length) do

        c = paths[0][start + completion.length, 1]
        c.downcase! if case_insensitive?
        completion += c

        pattern = Regexp.new("^.{#{start}}" + Regexp.escape(completion), \
                             case_insensitive?)

        paths.each do |path|
          if path !~ pattern
            completion.chop!
            done = true
            break
          end
        end
      end

      add_chars(completion) unless completion.length == 0
    end

    def del_char
      @input.chop!
    end

    def choose
      entries = matching_entries()

      if entries.length == 1
        name = entries.first()
      else
        # There are multiple entries, but we could still match one.
        name = find_match(entries)
        return if name.nil?
      end

      open_entry(name)
    end

    def open_entry(name)
      cleanup()
    end

    def cleanup
      # Only kill the buffer if we're sure it's the explorer.
      @displayer.close()
      Window.select(@calling_window)
      @settings.restore()
      @running = false
      VIM.message ""
    end
end


class BufferExplorer < DynamicExplorer
  public
    def initialize
      super
    end

    def run
      if !@running
        if VIM::Buffer.count == 1
          VIM.message "No other buffers"
        else
          @current_buffer_path = Pathname.new($curbuf.name)
          super
        end
      end
    end

  private
    def title
      '[DynamicExplorer-Buffers]'
    end

    def add_chars(s)
      @input += s
    end

    def case_insensitive?
      @input == @input.downcase
    end

    def input_match_string
      if @input.empty?
        return nil
      else
        str = "\\(^\\|#{@@COLUMN_SEPARATOR}\\)\\zs" + \
              Regexp.escape(@input).sub('\(','(').sub('\)',')') + \
              "\\ze\\(\\s*$\\|#{@@COLUMN_SEPARATOR}\\)"
        str += '\c' if case_insensitive?

        return str
      end
    end

    def buffer_match_string
      pwd = Pathname.new(eva("getcwd()"))
      relative_path = @current_buffer_path.relative_path_from(pwd).to_s
      str = "\\(^\\|#{@@COLUMN_SEPARATOR}\\)\\zs" + \
            Regexp.escape(relative_path) + \
            "\\ze\\(\\s*$\\|#{@@COLUMN_SEPARATOR}\\)"
      str += '\c' if case_insensitive?
      return str
    end


    def on_refresh
      # Highlighting for the current buffer name.
      exe "syntax clear DynExpCurrentBuffer"
      exe "syntax match DynExpCurrentBuffer \"#{buffer_match_string}\""
      super
    end

    def all_entries
      pwd = Pathname.new(eva("getcwd()"))

      # Generate a hash of the buffers.
      @buffers = Hash.new
      (0..VIM::Buffer.count-1).each do |i|

        # Skip the explorer buffer.
        next if VIM::Buffer[i].number == $curbuf.number

        path = Pathname.new(VIM::Buffer[i].name)
        relative = path.relative_path_from(pwd).to_s()

        @buffers[relative] = VIM::Buffer[i].number()
      end

      return @buffers.keys()
    end

    def pruning_regex
      Regexp.new("^" + Regexp.escape(@input), case_insensitive?)
    end

    def completion_start
      # Start the completion at our current input.
      @input.length
    end

    def find_match(entries)
      if case_insensitive?
        return entries.detect { |x| @input == x.downcase }
      else
        return entries.detect { |x| @input == x }
      end
    end

    def open_entry(path)
      number = @buffers[path]
      if !number.nil? and Window.select(@calling_window)
        exe "silent b #{number}"
      end
      super
    end
end


class FilesystemExplorer < DynamicExplorer
  public
    def initialize
      super
    end

    def key_pressed()
      i = eva("a:code_arg").to_i
    
      if (i == 10)    # Shift + Enter
        # Open all non-directories currently in view.
        matching_entries().each do |e|
          if descend?
            path = @input + e
          else
            path = File.dirname(@input) + File::SEPARATOR + e
          end

          load_file(path) unless File.directory?(path)
        end
        cleanup()
      else
        super
      end
    end

  private
    def title
    '[DynamicExplorer-Files]'
    end

    def add_chars(s)
      # Assumption: add_chars() will only receive enough chars at a time to
      # complete a single directory level, e.g. foo/, not foo/bar/

      @input += s

      if @input[-1,1] == File::SEPARATOR
        # Convert the named directory to a case-sensitive version.
        input_base = File.basename(@input)
        input_dir = File.dirname(@input)

        case_correct = Pathname.new(input_dir).entries.find { |p|
          p.basename.to_s.downcase == input_base
        }.to_s

        if (!case_correct.empty?)
          @input.sub!(/#{input_base}#{File::SEPARATOR}$/, \
                      case_correct + File::SEPARATOR)
        end
      end
    end

    def case_insensitive?
      if descend?
        true
      else
        File.basename(@input) == File.basename(@input).downcase
      end
    end

    def descend?
      # Descend into (list files of) the named subdirectory if a final '/'
      # has been typed.  This work-around is necessary because of the
      # conventions of basename and dirname.
      @input.empty? or \
      (Pathname.new(@input).directory? and @input =~ /#{File::SEPARATOR}$/)
    end

    def input_match_string
      if descend?
        nil
      else
        # Need to regex-escape the input, but not parentheses.
        escaped = Regexp.escape(File.basename(@input)).sub('\(','(') \
                                                      .sub('\)',')')
        str = "\\(^\\|#{@@COLUMN_SEPARATOR}\\)\\zs" + \
              escaped + \
              "\\ze\\(\\s*$\\|#{@@COLUMN_SEPARATOR}\\)"
        str += '\c' if case_insensitive?

        return str
      end
    end

    def all_entries
      input_path = Pathname.new(@input)
      view_path = Pathname.new(eva("getcwd()"))

      view_path += \
        if (descend?)
          # The last element in the path is a directory + '/' and we want to
          # see what's in it instead of the directory itself.
          input_path
        else
          input_path.dirname
        end

      # Generate an arry of the files
      files = Array.new
      view_path.each_entry do |file|
        name = file.basename.to_s
        next if name == "."   # Skip pwd

        # Don't show hidden files unless the user has typed a leading "." in
        # the current view_path.
        if name[0].chr == "."
          input_base = File.basename(@input)
          next if descend?
          next if input_base.empty?
          next if File.basename(@input)[0].chr != "."
        end

        if (view_path + file).directory?   # (Bug in Pathname.each_entry)
          name += File::SEPARATOR
        end
        files << name
      end

      return files
    end

    def pruning_regex
      if descend?
        # Nothing has been typed for this directory yet, so accept everything.
        Regexp.new(".")
      else
        Regexp.new("^" + Regexp.escape(File.basename(@input)), \
                   case_insensitive?)
      end
    end

    def completion_start
      if descend?
        # Nothing usable for completion available, so no completion base.
        "".length
      else
        File.basename(@input).length
      end
    end

    def find_match(entries)
      if descend?
        nil
      else
        target = File.basename(@input)

        if case_insensitive?
          return entries.detect { |x| target == x.downcase }
        else
          return entries.detect { |x| target == x }
        end
      end
    end

    def open_entry(name)
      if descend?
        path = @input + name
      else
        path = File.dirname(@input) + File::SEPARATOR + name
      end

      if File.directory?(path)
        # Recurse into the directory instead of opening it.
        tab_complete()
        @input += File::SEPARATOR unless @input =~ /#{File::SEPARATOR}$/
        refresh()
      else
        load_file(path)
        super
      end
    end

    def load_file(path)
      # Remove leading './' for files in pwd.
      path.sub!(/^\.\//,"")

      # Escape spaces.
      path.gsub!(' ', '\ ')

      exe "silent e #{path}" if Window.select(@calling_window)
    end
end


# Simplify switching between windows.
class Window
  public
    def Window.select(window)
      return true if window == $curwin

      start = $curwin

      # Try to select the given window.
      begin
        iterate()
      end while ($curwin != window) and ($curwin != start)

      if $curwin == window
        return true
      else
        # Failed -- re-select the starting window.
        iterate() while ($curwin != start)
        VIM.message "Can't find the correct window!"
        return false
      end
    end

  private
    def Window.previous
      exe "wincmd p"
    end

    def Window.iterate
      exe "wincmd w"
    end
end


# Save and restore settings when creating the explorer buffer.
class SavedSettings
  def initialize
    save()
  end

  def save
    @timeoutlen = eva "&timeoutlen" 

    @splitbelow = (eva "&splitbelow") == "1"
    @insertmode = (eva "&insertmode") == "1"
    @showcmd = (eva "&showcmd") == "1"
    @list = (eva "&list") == "1"

    @report = eva "&report"

    # Escape the quotes.
    @reg0 = (eva "@0").gsub(/"/,'\"')
    @reg1 = (eva "@1").gsub(/"/,'\"')
    @reg2 = (eva "@2").gsub(/"/,'\"')
    @reg3 = (eva "@3").gsub(/"/,'\"')
    @reg4 = (eva "@4").gsub(/"/,'\"')
    @reg5 = (eva "@5").gsub(/"/,'\"')
    @reg6 = (eva "@6").gsub(/"/,'\"')
    @reg7 = (eva "@7").gsub(/"/,'\"')
    @reg8 = (eva "@8").gsub(/"/,'\"')
    @reg9 = (eva "@9").gsub(/"/,'\"')
  end

  def restore
    set "timeoutlen=#{@timeoutlen}"

    if @splitbelow
      set "splitbelow"
    else
      set "nosplitbelow"
    end

    if @insertmode
      set "insertmode"
    else
      set "noinsertmode"
    end

    if @showcmd
      set "showcmd"
    else
      set "noshowcmd"
    end

    if @list
      set "list"
    else
      set "nolist"
    end

    exe "set report=#{@report}"

    exe 'let @0 = "' + @reg0 + '"'
    exe 'let @1 = "' + @reg1 + '"'
    exe 'let @2 = "' + @reg2 + '"'
    exe 'let @3 = "' + @reg3 + '"'
    exe 'let @4 = "' + @reg4 + '"'
    exe 'let @5 = "' + @reg5 + '"'
    exe 'let @6 = "' + @reg6 + '"'
    exe 'let @7 = "' + @reg7 + '"'
    exe 'let @8 = "' + @reg8 + '"'
    exe 'let @9 = "' + @reg9 + '"'
  end
end


# Manage the explorer buffer.
class Displayer

  public
    def initialize(title, column_separator, no_entries_string)
      @title = title
      @column_separator = column_separator
      @no_entries_string = no_entries_string

      @window = nil
      @buffer = nil
    end

    def create
      # Make a window for the displayer and move there.
      exe "silent! botright split #{@title}"

      @window = $curwin
      @buffer = $curbuf

      # Displayer buffer is special.
      exe "setlocal bufhidden=delete"
      exe "setlocal buftype=nofile"
      exe "setlocal nomodifiable"
      exe "setlocal noswapfile"
      exe "setlocal nowrap"
      exe "setlocal nonumber"
      exe "setlocal foldcolumn=0"
      exe "setlocal nocursorline"
      exe "setlocal nospell"
      exe "setlocal nobuflisted"

      set "timeoutlen=0"
      set "noinsertmode"
      set "noshowcmd"
      set "nolist"
      set "report=9999"

      #TODO -- cpoptions?
    end

    def print(entries)
      Window.select(@window) || return

      if entries.length == 0
        print_no_entries()
        return
      end

      col_count = column_count_upper_bound(entries)

      entries.sort!

      # Figure out the actual number of columns to use (yuck)
      cols = nil
      widths = nil
      while (col_count > 1) do

        cols = columnize(entries, col_count);

        widths = cols.map { |col|
          col.max { |a, b| a.length <=> b.length }.length
        }

        full_width = widths.inject { |sum, n| sum + n }
        full_width += @column_separator.length * (col_count - 1)

        if full_width <= $curwin.width
          break
        end

        col_count -= 1
      end

      if col_count <= 1
        cols = [entries]
        widths = [0]
      end

      print_columns(cols, widths)
    end

    def close
      # Only kill the buffer if we're sure it's the explorer.
      if Window.select(@window) and \
         $curbuf == @buffer and \
         $curbuf.name =~ /#{Regexp.escape(@title)}$/
          exe "bwipeout!"
          @window = nil
          @buffer = nil
      end
    end

  private

    def print_columns(cols, widths)
      unlock_and_clear()

      # Set the height to the length of the longest column.
      $curwin.height = cols.max { |a, b| a.length <=> b.length }.length

      (0..$curwin.height-1).each do |i|

        string = ""
        (0..cols.length-1).each do |j|
          break if cols[j][i].nil?
          string += cols[j][i]
          string += " " * [(widths[j] - cols[j][i].length), 0].max
          string += @column_separator
        end

        # Stretch the line to the length of the window with whitespace so that
        # we can "hide" the cursor in the corner.
        string += " " * [($curwin.width - string.length), 0].max

        $curwin.cursor = [i+1, 1]
        $curbuf.append(i, string)
      end

      # There's a blank line at the end of the buffer because of how
      # VIM::Buffer.append works.
      $curbuf.delete($curbuf.count)
      lock()
    end

    def print_no_entries
      unlock_and_clear()
      $curwin.height = 1
      $curbuf[1] = @no_entries_string.center($curwin.width, " ")
      lock()
    end

    def unlock_and_clear
      exe "setlocal modifiable"

      # Clear the explorer
      exe "silent %d"
    end

    def lock
      exe "setlocal nomodifiable"

      # Hide the cursor
      $curwin.cursor = [$curwin.height, $curwin.width - 1]
    end

    # Get a starting upper bound on the number of columns
    def column_count_upper_bound(strings)
      column_count = 0
      length = 0

      sorted_by_length = strings.sort {|x, y| x.length <=> y.length }

      sorted_by_length.each do |e|
        length += e.length
        break unless length < $curwin.width

        column_count += 1
        length += @column_separator.length
      end

      return column_count
    end

    def columnize(strings, column_count)
      rows = (strings.length / Float(column_count)).ceil

      # Break the array into sub arrays representing columns
      cols = strings.inject([[]]) { |array, e|
        if array.last.size < rows
          array.last << e
        else
          array << [e]
        end
        array
      }

      return cols
    end
end


$buffer_explorer = BufferExplorer.new
$filesystem_explorer = FilesystemExplorer.new


EOF

else
  echohl ErrorMsg | echo "Sorry, DynamicExplorer requires ruby."
  echohl none
endif


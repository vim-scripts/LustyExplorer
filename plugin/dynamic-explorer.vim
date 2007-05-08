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
" Release Date: Tuesday, May 8, 2007
"      Version: 1.0
"               Inspired by Viewglob and by Jeff Lanzarotta's Buffer Explorer
"               plugin.
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
"               (similar to "smartcase" mode in VIM).
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
" - expand ~ to $HOME

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
  ruby $filesystemExplorer.run
endfunction

function! s:BufferExplorerStart()
  ruby $bufferExplorer.run
endfunction

function! FilesystemExplorerCancel()
  ruby $filesystemExplorer.cancel
endfunction

function! BufferExplorerCancel()
  ruby $bufferExplorer.cancel
endfunction

function! FilesystemExplorerKeyPressed(code_arg)
  ruby $filesystemExplorer.keyPressed
endfunction

function! BufferExplorerKeyPressed(code_arg)
  ruby $bufferExplorer.keyPressed
endfunction

ruby << EOF
require 'pathname'

def exe(s)
  VIM::command s
end

def eva(s)
  VIM::evaluate s
end

def set(s)
  VIM::set_option s
end


def previousWindow
  exe "wincmd p"
end

def iterateWindow
  exe "wincmd w"
end

def selectWindow(window)
  return true if window == $curwin

  first = $curwin

  # Try to select the given window.
  begin
    iterateWindow()
  end while ($curwin != window) and ($curwin != first)

  if $curwin == window
    return true
  else
    # Failed -- re-select the starting window.
    iterateWindow() while ($curwin != first)
    return false
  end
end


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


class DynamicExplorer
  private
    @@PROMPT = "> "
    @@COLUMN_SEPARATOR = "    "
    @@NO_ENTRIES_STRING = "-- NO ENTRIES --" 

  public
    def initialize
      @settings = SavedSettings.new
      @input = ""
      @running = false
      @hasSyntax = (eva('has("syntax")') != "0")
    end

    def run
      if !@running
        @input = ""
        @settings.save()
        @running = true
        @openWindow = $curwin
        createSpecialBuffer()
        refresh()
      end
    end

    def keyPressed()
      i = Integer(eva("a:code_arg"))

      case i
        when 32..126          # Printable characters
          c = i.chr
          addChars(c)
        when 8                # Backspace
          delChar()
        when 9                # Tab
          tabComplete()
        when 13               # Enter
          choose()
          return
      end

      refresh()
    end

    def cancel()
      close()
      cleanup()
    end

  private

    def close()
      if selectWindow(@explorerWindow)
        # Only cleanup and exit if we're sure the current buffer is the
        # explorer.
        if $curbuf.number == @specialBufNum and \
           $curbuf.name =~ /#{Regexp.escape(title())}$/
          exe "bwipeout!"
        end
      else
        VIM::message "Could not locate explorer window!"
      end
    end

    def refresh
      printEntries()
      VIM::message @@PROMPT + @input
    end

    def createSpecialBuffer
      # Make a minimal window for the explorer and move there.
      exe "silent! botright split #{title}"

      @specialBufNum = $curbuf.number
      @explorerWindow = $curwin

      # Explorer is special
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

      # Non-special printable characters.
      printables =  '/!"#$%&\'()*+,-.0123456789:<=>?#@"' + \
                    'ABCDEFGHIJKLMNOPQRSTUVWXYZ' + \
                    '[]^_`abcdefghijklmnopqrstuvwxyz{}~'

      mapCommand = "noremap <silent> <buffer> "

      # Grab all input by mapping to a function call.
      printables.each_byte do |b|
        exe mapCommand + "<Char-#{b}> :call #{self.class}KeyPressed(#{b})<CR>"
      end

      # Special characters
      exe mapCommand + "<Tab>    :call #{self.class}KeyPressed(9)<CR>"
      exe mapCommand + "<Bslash> :call #{self.class}KeyPressed(92)<CR>"
      exe mapCommand + "<Space>  :call #{self.class}KeyPressed(32)<CR>"
      exe mapCommand + "\026|    :call #{self.class}KeyPressed(124)<CR>"
      exe mapCommand + "<BS>     :call #{self.class}KeyPressed(8)<CR>"

      exe mapCommand + "<CR>     :call #{self.class}KeyPressed(13)<CR>"
      exe mapCommand + "<S-CR>   :call #{self.class}KeyPressed(10)<CR>"

      exe mapCommand + "<Esc>    :call #{self.class}Cancel()<CR>"
      exe mapCommand + "<C-c>    :call #{self.class}Cancel()<CR>"

      if @hasSyntax
        exe 'syntax match DynExpDir "\zs\S\+\ze/" contains=DynExpSlash'
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

    def onPrintEntries
      # Blank
    end

    def printEntries
      onPrintEntries()

      exe "syntax clear DynExpMatch"
      if !inputMatchString.nil?
        exe "syntax match DynExpMatch \"#{inputMatchString}\""
      end

      entries = matchingEntries().keys().sort()

      # Get a starting upper bound on the number of columns
      # FIXME -- is this broken?
      col_count = 0
      len = 0
      entries.each() do |e|
        len += e.length
        if (len < $curwin.width())
          col_count += 1
          len += @@COLUMN_SEPARATOR.length
        else
          break
        end
      end

      # Figure out the actual number of columns to use (yuck)
      while (col_count > 1) do

        cols = columnize(entries, col_count);

        widths = cols.map { |col|
          col.max { |a, b| a.length <=> b.length }.length
        }

        full_width = widths.inject { |sum, n| sum + n }
        full_width += @@COLUMN_SEPARATOR.length * (col_count - 1)

        if full_width <= $curwin.width
          break
        end

        col_count -= 1
      end

      if col_count <= 1
        col_count = 1
        cols = [entries]
        widths = [0]
      end

      exe "setlocal modifiable"

      # Clear the explorer
      exe "silent %d"

      # Set the height to the length of the longest column.
      $curwin.height = cols.max { |a, b| a.length <=> b.length }.length

      #$curwin.cursor = [1, 1]

      # Layout and print the rows.
      if entries.length == 0
        $curbuf.append(0, @@NO_ENTRIES_STRING.center($curwin.width, " "))
      else

        (0..$curwin.height-1).each do |i|

          string = ""
          (0..cols.length-1).each do |j|
            break if cols[j][i].nil?
            string += cols[j][i]
            string += " " * [(widths[j] - cols[j][i].length), 0].max
            string += @@COLUMN_SEPARATOR
          end

          # Stretch the line to the length of the window so that we can "hide"
          # the cursor.
          string += " " * [($curwin.width - string.length), 0].max

          $curwin.cursor = [i+1, 1]
          $curbuf.append(i, string)
        end
      end

      # There's a blank line at the end of the buffer because of how
      # VIM::Buffer.append works.
      $curbuf.delete($curbuf.count)

      exe "setlocal nomodifiable"

      # "Hide" the cursor.
      #$curwin.cursor = [$curwin.height, $curwin.width]
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

    def matchingEntries()

      entries = allEntries()
      input_regex = pruningRegex()

      # Only return entries whose names match our input.
      pruned = Hash.new
      entries.each do |key, value|
        if key =~ input_regex
          pruned[key] = value
        end
      end

      return pruned
    end

    def tabComplete()
      paths = matchingEntries().keys()

      return if paths.length <= 0

      start = completionStart()

      # Tab complete (yuck)
      done = false
      completion = ""
      while (!done and start + completion.length < paths[0].length) do

        c = paths[0][start + completion.length, 1]
        c.downcase! if caseInsensitive?
        completion += c

        pattern = Regexp.new("^.{#{start}}" + Regexp.escape(completion), \
                             caseInsensitive?)

        paths.each do |path|
          if path !~ pattern
            completion.chop!
            done = true
            break
          end
        end
      end

      addChars(completion) unless completion.length == 0
    end

    def delChar
      @input.chop!
    end

    def choose()
      entries = matchingEntries()

      if entries.length == 1
        name = entries.to_a[0][0]
        number = entries.to_a[0][1]
      else
        # There are multiple entries, but we could still match one.
        name = findMatch(entries)
        return if name.nil?
        number = entries[name]
      end

      openEntry(name, number)
    end

    def openEntry(name, number)
      close()
      cleanup()
    end

    def cleanup
      selectWindow(@openWindow)
      @settings.restore()
      @running = false
      VIM::message ""
    end

end


class BufferExplorer < DynamicExplorer
  public
    def initialize
      super
    end

    def run
      super if @running
      if VIM::Buffer.count == 1
        VIM::message "No other buffers"
      else
        @current_buffer_path = Pathname.new($curbuf.name)
        super
      end
    end

  private
    def title
      '[DynamicExplorer-Buffers]'
    end

    def addChars(s)
      @input += s
    end

    def caseInsensitive?
      @input == @input.downcase
    end

    def inputMatchString
      if @input.empty?
        return nil
      else
        str = "\\(^\\|#{@@COLUMN_SEPARATOR}\\)\\zs" + \
              Regexp.escape(@input) + \
              "\\ze\\(\\s*$\\|#{@@COLUMN_SEPARATOR}\\)"
        str += '\c' if caseInsensitive?

        return str
      end
    end

    def bufferMatchString
      pwd = Pathname.new(eva("getcwd()"))
      relative_path = @current_buffer_path.relative_path_from(pwd)
      str = "\\(^\\|#{@@COLUMN_SEPARATOR}\\)\\zs" + \
            Regexp.escape(relative_path.to_s) + \
            "\\ze\\(\\s*$\\|#{@@COLUMN_SEPARATOR}\\)"
      str += '\c' if caseInsensitive?
      return str
    end


    def onPrintEntries
      # Highlighting for the current buffer name.
      exe "syntax clear DynExpCurrentBuffer"
      exe "syntax match DynExpCurrentBuffer \"#{bufferMatchString}\""
      super
    end

    def allEntries
      pwd = Pathname.new(eva("getcwd()"))

      # Generate a hash of the buffers.
      buffers = Hash.new
      (0..VIM::Buffer.count-1).each do |i|

        # Skip the explorer buffer.
        next if VIM::Buffer[i].number == $curbuf.number

        path = Pathname.new(VIM::Buffer[i].name)
        relative = path.relative_path_from(pwd).to_s()

        buffers[relative] = VIM::Buffer[i].number()
      end

      return buffers
    end

    def pruningRegex
      Regexp.new("^" + Regexp.escape(@input), caseInsensitive?)
    end

    def completionStart
      # Start the completion at our current input.
      @input.length
    end

    def findMatch(entries)
      if caseInsensitive?
        return entries.keys.detect { |x| @input == x.downcase }
      else
        return @input if entries[@input]
      end
    end

    def openEntry(path, number)
      if selectWindow(@openWindow)
        exe "silent b #{number}"
      else
        VIM::message "Can't find the correct window!"
      end
      super
    end
end


class FilesystemExplorer < DynamicExplorer
  public
    def initialize
      super
    end

    def keyPressed()
      i = Integer(eva("a:code_arg"))
    
      if (i == 10)    # Shift + Enter
        # Open all non-directories currently in view.
        matchingEntries().keys().each do |e|
          if descend?
            path = @input + e
          else
            path = File.dirname(@input) + File::SEPARATOR + e
          end

          loadFile(path) unless File.directory?(path)
        end
        close()
        cleanup()
      else
        super
      end
    end

  private
    def title
    '[DynamicExplorer-Files]'
    end

    def addChars(s)
      # Assumption: addChars() will only receive enough chars at a time to
      # complete a single directory level, e.g. foo/, not foo/bar/

      @input += s

      if @input =~ /#{File::SEPARATOR}$/
        # Convert the named directory to a case-sensitive version.
        input_base = File.basename(@input)
        input_dir = File.dirname(@input)

        case_correct = Pathname.new(input_dir).entries.find { |p|
          p.basename.to_s.downcase == input_base
        }.to_s

        if (!case_correct.empty?)
          @input.sub!(/#{input_base + File::SEPARATOR}$/, \
                      case_correct + File::SEPARATOR)
        end
      end
    end

    def caseInsensitive?
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

    def inputMatchString
      if descend?
        nil
      else
        str = "\\(^\\|#{@@COLUMN_SEPARATOR}\\)\\zs" + \
              Regexp.escape(File.basename(@input)) + \
              "\\ze\\(\\s*$\\|#{@@COLUMN_SEPARATOR}\\)"
        str += '\c' if caseInsensitive?

        return str
      end
    end

    def allEntries
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

      # Generate a nil hash of the files
      files = Hash.new
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

        if (view_path + file).directory?   # (Bug in Pathname::each_entry)
          name += File::SEPARATOR
        end
        files[name] = "blank"
      end

      return files
    end

    def pruningRegex
      if descend?
        # Nothing has been typed for this directory yet, so accept everything.
        Regexp.new(".", caseInsensitive?)
      else
        Regexp.new("^" + Regexp.escape(File.basename(@input)), caseInsensitive?)
      end
    end

    def completionStart
      if descend?
        # Nothing usable for completion available, so no completion base.
        "".length
      else
        File.basename(@input).length
      end
    end

    def findMatch(entries)
      if descend?
        nil
      else
        target = File.basename(@input)

        if caseInsensitive?
          return entries.keys.detect { |x| target == x.downcase }
        else
          return target if entries[target]
        end
      end
    end

    def openEntry(name, number)
      if descend?
        path = @input + name
      else
        path = File.dirname(@input) + File::SEPARATOR + name
      end

      if File.directory?(path)
        # Recurse into the directory instead of opening it.
        tabComplete()
        @input += File::SEPARATOR unless @input =~ /#{File::SEPARATOR}$/
        refresh()
      else
        loadFile(path)
        super
      end
    end

    def loadFile(path)
      # Remove leading './' for files in pwd.
      path.sub!(/^\.\//,"")

      if selectWindow(@openWindow)
        exe "silent e #{path}"
      else
        VIM::message "Can't find the correct window!"
      end
    end
end

$bufferExplorer = BufferExplorer.new
$filesystemExplorer = FilesystemExplorer.new

EOF

else
  echohl ErrorMsg | echo "Sorry, DynamicExplorer requires ruby."
  echohl none
endif



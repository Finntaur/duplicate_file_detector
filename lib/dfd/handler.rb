require 'highline'

require File.join(__dir__, 'duplicate_file_set')
require File.join(__dir__, 'trasher')

module DFD
  AUTO_KEEP = %i(oldest newest first last).freeze

  class Handler

    def initialize(duplicates, options: nil)
      @duplicates = duplicates
      @options = options
      @colors = {
        file: "\e[33;1m",
        normal: "\e[0m",
        input: "\e[32;1m",
        header: "\e[34;1m",
        label: "\e[35;1m",
        delete: "\e[31;3m"
      }
      @colors = nil if @options.no_color
      @highline = HighLine.new
      @trasher = DFD::Trasher.new(mode: @options.trash ? :trash : :remove)
    end

    def start
      STDOUT.puts("#{@duplicates.size} duplicates detected. Processing ...")
      counter_format = "%#{@duplicates.size.to_s.size}i"
      @duplicates.each_with_index do |set, index|
        header = "[#{counter_format % (index + 1)}/#{@duplicates.size}] "
        header += "#{'=' * (terminal_width - header.size)}"
        STDOUT.puts("#{@colors&.[](:header)}#{header}#{@colors&.[](:normal)}")
        print(set)
        keep = ( auto_keep(set) or prompt(set) )

        if keep.uniq.size != set.count
          remove_copies(set, keep)
        else
          STDOUT.puts("Keeping all copies ...")
        end
      end
    end

    private

    def terminal_width
      [@highline.output_cols, 32].max
    end

    def remove_copies(set, keep)
      raise ScriptError.new('Will not delete all copies!') if keep.size <= 0
      set.files.each_with_index do |file, index|
        next if keep.include?(index)
        action = ( @options.dry_run ? 'Would delete' : 'Delete' )
        STDOUT.puts("#{action} #{@colors&.[](:delete)}#{file}#{@colors&.[](:normal)}")
        @trasher.trash(file) unless @options.dry_run
      end
    end

    def print(set)
      set.files.each_with_index do |file, index|
        stat = File.stat(file)
        oldest = ( set.oldest == file ? "#{@colors&.[](:label)}(OLDEST)#{@colors&.[](:normal)}" : '' )
        newest = ( set.newest == file ? "#{@colors&.[](:label)}(NEWEST)#{@colors&.[](:normal)}" : '' )
        STDOUT.puts("#{'%3i' % (index + 1)}) #{@colors&.[](:file)}#{file}#{@colors&.[](:normal)}")
        STDOUT.puts("       Created  : #{stat.birthtime} #{oldest}")
        STDOUT.puts("       Modified : #{stat.mtime} #{newest}")
      end
      STDOUT.puts("     #{'-' * (terminal_width - 5)}")
      STDOUT.puts("       Filesize : #{set.size} B")
      STDOUT.puts("       SHA512   : #{set.sha512}")
      STDOUT.puts("       MD5      : #{set.md5}")
    end

    def auto_keep(set)
      case @options.auto_keep
      when :oldest
        [set.files.index(set.oldest)]
      when :newest
        [set.files.index(set.newest)]
      when :first
        [0]
      when :last
        [set.count - 1]
      else
        nil
      end
    end

    def prompt(set)
      ignored = [0]
      keepers = []
      while not ignored.empty? do
        STDOUT.print("Space separated list of file numbers to keep, empty for all: #{@colors&.[](:input)}")
        keepers = STDIN.gets.strip.split.uniq
        STDOUT.print("#{@colors&.[](:normal)}")

        ignored = keepers.select { |x| not (1..set.count).include?(x.to_i) }.compact
        STDOUT.puts("Did not understand: #{ignored.join(' ')}") unless ignored.empty?

        keepers = keepers.collect { |x| x.to_i - 1 }.sort.uniq.compact
        keepers = (0...set.count).to_a if keepers.empty?
      end
      return keepers
    end

  end
end

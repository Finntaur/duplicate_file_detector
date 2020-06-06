require 'optparse'
require 'progress_bar'

require File.join(__dir__, 'directory')
require File.join(__dir__, 'cache')
require File.join(__dir__, 'analyzed_file')
require File.join(__dir__, 'handler')
require File.join(__dir__, 'file_filter')

module DFD
  class Detector
    VERSION = '1.0'.freeze

    class Options
      attr_accessor(
        :paths, :include_all, :recursive,
        :quiet, :cache, :dry_run, :no_color,
        :auto_keep, :filter
      )

      def initialize
        @paths = []
        @recursive = false
        @include_all = false
        @quiet = false
        @parser = nil
        @dry_run = false
        @no_color = false
        @auto_keep = nil
        @filter = DFD::FileFilter.new
      end

      def set(parser:)
        @parser = parser
        @parser.banner = 'Usage: dfd [OPTIONS] PATH ...'
        @parser.separator('')
        @parser.separator('Available options:')

        set_include_all_option
        set_clear_cache_option
        set_recursive_option
        set_quiet_option
        set_dry_run_option
        set_no_color_option
        set_auto_keep_option
        set_ignore_filter_option

        @parser.on_tail('-h', '--help', 'Show this help') do
          help
        end

        @parser.on_tail('-v', '--version', 'Display version') do
          version
        end

        @paths = @parser.default_argv
      end

      def help
        STDOUT.puts(@parser)
        exit
      end

      def version
        STDOUT.puts(DFD::Detector::VERSION)
        exit
      end

      private

      def set_include_all_option
        @parser.on('-a', '--all', 'Include hidden files in analysis') do
          @include_all = true
        end
      end

      def set_quiet_option
        @parser.on('-q', '--quiet', 'Silence all unnecessary output') do
          @quiet = true
        end
      end

      def set_recursive_option
        @parser.on('-r', '--recursive', 'Recurse into subdirectories') do
          @recursive = true
        end
      end

      def set_no_color_option
        @parser.on('--no-color', 'Do not use colors in output') do
          @no_color = true
        end
      end

      def set_clear_cache_option
        @parser.on('--clear-cache', 'Just clear the cache and exit, ignore all other options') do
          $STDOUT = STDOUT
          DFD::Cache.new.purge!(all: true)
          exit
        end
      end

      def set_dry_run_option
        @parser.on('-n', '--dry-run', 'Take no action on the duplicates') do
          @dry_run = true
        end
      end

      def set_auto_keep_option
        @parser.on(
          '--auto KEEP',
          DFD::AUTO_KEEP,
          "Automatically delete duplicates, keeping the copy matching KEEP criteria (#{DFD::AUTO_KEEP.join(', ')})"
        ) do |keep|
          @auto_keep = keep
        end
      end

      def set_ignore_filter_option
        @parser.on('--ignore SOURCE', 'Ignore files matching regular expressions provided in SOURCE file') do |source|
          @filter.load(source)
        end
      end
    end

    # -------------------------------------------------------------------------

    def initialize(arguments = nil)
      @options = DFD::Detector::Options.new
      set_options(arguments ? arguments : [])
      @directory = DFD::Directory.new
      @cache = DFD::Cache.new
      @options.filter.load(File.join(ENV['HOME'], '.dfd.ignore')) unless @options.filter.loaded
    rescue OptionParser::InvalidArgument, OptionParser::MissingArgument
      @options.paths.clear
    end

    def execute
      @options.help if @options.paths.empty?
      $STDOUT = ( @options.quiet ? nil : STDOUT )

      locate_files
      files_to_analyze = @directory.clone
      @cache.purge!
      $STDOUT&.puts('Loading cache ...')
      progress_bar = ($STDOUT ? ProgressBar.new(@directory.size) : nil)
      @directory.files.each do |path|
        files_to_analyze.remove(path) if @cache.cached?(path)
        progress_bar&.increment!
      end
      analyze(files_to_analyze)

      duplicates = []

      $STDOUT&.puts('Looking for duplicates ...')
      progress_bar = ($STDOUT ? ProgressBar.new(@directory.size) : nil)
      @directory.files.each do |path|
        dups = @cache.find_duplicates(path)
        duplicates << dups if 1 < dups.count
        progress_bar&.increment!
      end
      duplicates.uniq!(&:files)

      DFD::Handler.new(duplicates, options: @options).start

    rescue Interrupt
      STDOUT.puts('Aborted!')
    end

    private

    def analyze(directory)
      return if directory.size <= 0
      $STDOUT&.puts('Analyzing files ...')
      progress_bar = ($STDOUT ? ProgressBar.new(directory.size) : nil)
      directory.files.each do |path|
        @cache.add(DFD::AnalyzedFile.new(path))
        progress_bar&.increment!
      end
    end

    def locate_files
      $STDOUT&.puts('Indexing files ...')
      progress_bar = ($STDOUT ? ProgressBar.new(@options.paths.size) : nil)
      @options.paths.each do |path|
        @directory.add(
          path,
          recursive: (@options.recursive ? true : 1),
          include_all: @options.include_all,
          filter: @options.filter
        )
        progress_bar&.increment!
      end
      @directory.tidy!
    end

    def set_options(arguments)
      OptionParser.new do |parser|
        @options.set(parser: parser)
        parser.parse!
      end
    end

  end
end

# Allow direct execution.
DFD::Detector.new(ARGV).execute if __FILE__ == $0

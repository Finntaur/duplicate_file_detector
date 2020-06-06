module DFD
  class FileFilter

    attr_reader(:loaded)

    def initialize
      @globs = []
    end

    def add(glob)
      @globs << glob if glob.is_a?(String)
    end

    def load(source)
      if File.file?(source) and File.readable?(source)
        File.readlines(source).each do |line|
          next if line.strip.empty? or line.strip.match(/^#/)
          @globs << line.strip
        end
      end

      @loaded = true
    end

    def allows?(path)
      return true if @globs.empty?
      @globs.each do |ignore|
        return false if File.fnmatch(ignore, File.basename(path), File::FNM_DOTMATCH)
        return false if (
          ignore.end_with?('/') and
          File.directory?(path) and
          File.fnmatch(ignore.chop, File.basename(path), File::FNM_DOTMATCH)
        )
      end

      true
    end

  end
end

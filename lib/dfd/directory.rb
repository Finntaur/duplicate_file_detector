module DFD
  class Directory
    attr_reader(:files)

    def initialize
      @files = []
    end

    def add(path, recursive:, include_all:)
      absolute_path = File.absolute_path(path)
      return if File.symlink?(absolute_path)
      if File.file?(absolute_path)
        @files << absolute_path
      elsif File.directory?(absolute_path) and recursive
        flags = ( include_all ? File::FNM_DOTMATCH : 0 )
        begin
          Dir.glob('*', flags, base: absolute_path).each do |sub|
            next if sub.match(/^\.+$/)
            add(
              File.join(absolute_path, sub),
              recursive: (true == recursive),
              include_all: include_all
            )
          end
        rescue Errno::EPERM
          # Simply skip any unauthorized directories.
        end
      end
    end

    def remove(path)
      @files.delete(path)
    end

    def tidy!
      @files.compact!
      @files.sort!
      @files.uniq!

      self
    end

    def size
      @files.size
    end

    def clone
      copy = Directory.new
      @files.each do |path|
        copy.files << path.dup
      end

      copy
    end
  end
end

module DFD
  class DuplicateFileSet
    attr_reader(:files, :size, :sha512, :md5)

    def initialize(files:, size:, sha512:, md5:)
      @files = files
      @size = size
      @sha512 = sha512
      @md5 = md5
    end

    def count
      @files.size
    end

  end
end

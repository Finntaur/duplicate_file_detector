require File.expand_path(File.join(__dir__, 'support', 'configuration'))

describe DFD::Cache do

  let(:analyzed_file) { DFD::AnalyzedFile.new(__FILE__) }
  let(:testfile1) { DFD::AnalyzedFile.new(File.join(__dir__, 'assets', 'testfile-1.txt')) }
  let(:testfile2) { DFD::AnalyzedFile.new(File.join(__dir__, 'assets', 'testfile-2.txt')) }

  before(:all) do
    @database = 'test_cache.sqlite3'
    @cache = DFD::Cache.new('test_cache.sqlite3')
  end

  describe '.new' do
    it 'creates missing cache database' do
      database = @database + '-tmp'
      File.delete(database) if File.exists?(database)
      expect(File.exists?(database)).to eq false
      DFD::Cache.new(database)
      expect(File.exists?(database)).to eq true
      expect { SQLite3::Database.new(database).integrity_check }.not_to raise_error
      File.delete(database)
    end

    it 'not to touch existing database' do
      DFD::Cache.new(@database) unless File.exists?(@database)
      pre_init = DFD::AnalyzedFile.new(@database)
      cache = DFD::Cache.new(@database)
      expect(File.exists?(@database)).to eq true
      post_init = DFD::AnalyzedFile.new(@database)
      expect(post_init.sha512 + post_init.md5).to eq(pre_init.sha512 + pre_init.md5)
      cache.close
    end

  end

  describe '#valid?' do
    it 'throws exception when given invalid args' do
      expect { @cache.valid?(nil) }.to raise_error(ArgumentError)
      expect { @cache.valid?(true) }.to raise_error(ArgumentError)
    end

    it 'returns false for non-existing files' do
      expect(@cache.valid?(build(:cached_file))).to be false
    end

    it 'returns false for files with different timestamps' do
      cached_file = build(
        :cached_file,
        path: File.absolute_path(__FILE__),
        size: File.stat(__FILE__).size,
        millis: (File.stat(__FILE__).mtime.subsec * 1000).round
      )
      expect(@cache.valid?(cached_file)).to be false
    end

    it 'returns false for files with different milliseconds' do
      cached_file = build(
        :cached_file,
        path: File.absolute_path(__FILE__),
        size: File.stat(__FILE__).size,
        updated_at: File.stat(__FILE__).mtime.round.to_s,
        millis: (File.stat(__FILE__).mtime.subsec * 1000 + 1).round
      )
      expect(@cache.valid?(cached_file)).to be false
    end

    it 'returns false for files with different file sizes' do
      cached_file = build(
        :cached_file,
        path: File.absolute_path(__FILE__),
        updated_at: File.stat(__FILE__).mtime.round.to_s,
        millis: (File.stat(__FILE__).mtime.subsec * 1000).round
      )
      expect(@cache.valid?(cached_file)).to be false
    end

    it 'returns true for files with matching timestamps and sizes' do
      cached_file = build(
        :cached_file,
        path: File.absolute_path(__FILE__),
        size: File.stat(__FILE__).size,
        updated_at: File.stat(__FILE__).mtime.round.to_s,
        millis: (File.stat(__FILE__).mtime.subsec * 1000).round
      )
      expect(@cache.valid?(cached_file)).to be true
    end
  end

  describe '#add' do
    it 'appends analyzed files to the cache' do
      @cache.purge!(all: true)
      file = analyzed_file
      @cache.add(file)
      expect(@cache.cached?(file.path)).to be true
    end
  end

  describe '#size' do
    it 'returns the number of rows in the cache' do
      @cache.purge!(all: true)
      expect(@cache.size).to be 0
      for i in 1..5 do
        file = build(:cached_file)
        @cache.add(DFD::AnalyzedFile.new(File.join(__dir__, 'assets', "testfile-#{i}.txt")))
        expect(@cache.size).to be i
      end
    end
  end

  describe '#purge!' do
    it 'should wipe everything' do
      file = analyzed_file
      @cache.purge!(all: true)
      expect(@cache.size).to be 0
    end

    it 'should purge old entries' do
      file = testfile2
      @cache.add(testfile2)
      expect(@cache.cached?(file.path)).to be true
      @cache.purge!
      expect(@cache.cached?(file.path)).to be true
      file_io = File.open(file.path, 'w')
      file_io.write((rand * 1e8).floor.to_s)
      file_io.close
      @cache.purge!
      expect(@cache.cached?(file.path)).to be false
    end
  end

end

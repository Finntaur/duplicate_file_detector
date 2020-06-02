require File.expand_path(File.join(__dir__, 'support', 'configuration'))

describe DFD::AnalyzedFile do

  let(:this_file) { DFD::AnalyzedFile.new(__FILE__) }

  describe '.new' do

    it 'throws error on when path does not point to regular files' do
      expect { DFD::AnalyzedFile.new(nil) }.to raise_error(TypeError)
      expect { DFD::AnalyzedFile.new('.') }.to raise_error(ArgumentError)
    end

    it 'succeeds for existing files' do
      expect(this_file).to be_kind_of(DFD::AnalyzedFile)
    end

  end

  describe '#path' do
    it 'resolves absolute paths' do
      expect(this_file.path).to eq File.absolute_path(__FILE__)
    end
  end

  describe '#size' do
    it 'read file sizes from file stat' do
      expect(this_file.size).to eq File.stat(__FILE__).size
    end
  end

  describe '#updated_at' do
    it 'read modification timestamp from file stat' do
      expect(this_file.updated_at).to eq File.stat(__FILE__).mtime.round
    end
  end

  describe '#millis' do
    it 'read milliseconds from modification timestamp from file stat' do
      expect(this_file.millis).to eq (File.stat(__FILE__).mtime.subsec * 1000).round
    end
  end

  describe '#sha512' do
    it 'computes SHA512 checksum' do
      expect(this_file.sha512).to eq Digest::SHA512.file(__FILE__).hexdigest
    end
  end

  describe '#md5' do
    it 'computes MD5 checksum' do
      expect(this_file.md5).to eq Digest::MD5.file(__FILE__).hexdigest
    end
  end

end

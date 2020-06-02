require File.expand_path(File.join(__dir__, 'support', 'configuration'))

describe DFD::CachedFile do

  let(:sample) { build(:cached_file) }

  describe '.new' do
    it 'can be built by factories' do
      expect(build(:cached_file)).to be_kind_of(DFD::CachedFile)
    end
  end

  describe '#id' do
    it 'should be integer' do
      expect(sample.id).to be_kind_of(Numeric)
    end
  end

  describe '#path' do
    it 'should be a string' do
      expect(sample.path).to be_kind_of(String)
    end
  end

  describe '#size' do
    it 'should be an integer' do
      expect(sample.size).to be_kind_of(Numeric)
    end
  end

  describe '#updated_at' do
    it 'should be a Time object' do
      expect(sample.updated_at).to be_kind_of(Time)
    end
  end

  describe '#millis' do
    it 'should be an integer' do
      expect(sample.millis).to be_kind_of(Numeric)
    end
  end

  describe '#sha512' do
    it 'should be a SHA512 string' do
      expect(sample.sha512).to match(/^[0-9a-f]{128}$/i)
    end
  end

  describe '#md5' do
    it 'should be a MD5 string' do
      expect(sample.md5).to match(/^[0-9a-f]{32}$/i)
    end
  end

end

require File.expand_path(File.join(__dir__, 'support', 'configuration'))

describe DFD::Directory do

  describe '#add' do
    it 'should add files to the directory'

    it 'should add items from subdirectories'

    it 'should recurse to directories'

    it 'should include hidden files'

    it 'should not include hidden files'
  end

  describe '#tidy!' do
    it 'should provide only unique path names'

    it 'should be chainable'
  end

  describe '#clone' do

    it 'should produce a copy' do
      directory = DFD::Directory.new
      directory.add(__FILE__, recursive: false, include_all: false)
      copy = directory.clone
      expect(copy.files).to eq directory.files
    end

    it 'should not point to original object' do
      directory = DFD::Directory.new
      directory.add(__FILE__, recursive: false, include_all: false)
      copy = directory.clone
      directory.files.first.sub!(/(?<=.)$/, '.txt')
      expect(copy.files).to_not eq directory.files
    end

  end

end

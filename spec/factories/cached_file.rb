require 'digest'

FactoryBot.define do
  factory(:cached_file, class: DFD::CachedFile) do
    id { (rand * 1e6).to_i }
    path { (rand * 1e8).round.to_s + '.txt' }
    size { (rand * 1e8).to_i.abs }
    updated_at { (Time.now - (rand * 1e8)).to_s }
    millis { (rand * 1e4).to_i.abs }
    sha512 { Digest::SHA512.hexdigest((rand * 1e6).to_s) }
    md5 { Digest::MD5.hexdigest((rand * 1e6).to_s) }

    initialize_with { new([id, path, size, updated_at, millis, sha512, md5]) }
  end
end

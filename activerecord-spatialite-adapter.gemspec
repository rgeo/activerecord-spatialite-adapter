::Gem::Specification.new do |s_|
  s_.name = 'activerecord-spatialite-adapter'
  s_.summary = 'An ActiveRecord adapter for SpatiaLite, based on RGeo.'
  s_.description = "This is an ActiveRecord connection adapter for the SpatiaLite extension to the Sqlite3 database. It is based on the stock sqlite3 adapter, but provides built-in support for spatial databases using SpatiaLite. It uses the RGeo library to represent spatial data in Ruby."
  s_.version = "#{::File.read('Version').strip}.build#{::Time.now.utc.strftime('%Y%m%d%H%M%S')}"
  s_.author = 'Daniel Azuma'
  s_.email = 'dazuma@gmail.com'
  s_.homepage = "http://virtuoso.rubyforge.org/activerecord-spatialite-adapter"
  s_.rubyforge_project = 'virtuoso'
  s_.required_ruby_version = '>= 1.8.7'
  s_.files = ::Dir.glob("lib/**/*.{rb,rake}") +
    ::Dir.glob("test/**/*.rb") +
    ::Dir.glob("*.rdoc") +
    ['Version']
  s_.extra_rdoc_files = ::Dir.glob("*.rdoc")
  s_.test_files = ::Dir.glob("test/**/tc_*.rb")
  s_.platform = ::Gem::Platform::RUBY
  s_.add_dependency('rgeo-activerecord', '~> 0.4.0')
  s_.add_dependency('sqlite3', '>= 1.3.3')
end

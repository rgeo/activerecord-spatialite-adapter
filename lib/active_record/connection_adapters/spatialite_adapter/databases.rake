# -----------------------------------------------------------------------------
#
# Rakefile changes for SpatiaLite adapter
#
# -----------------------------------------------------------------------------
# Copyright 2010 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# -----------------------------------------------------------------------------
;


require 'rgeo/active_record/task_hacker'


class Object
  alias_method :create_database_without_spatialite, :create_database
  alias_method :drop_database_without_spatialite, :drop_database
end


def create_database(config_)
  if config_['adapter'] == 'spatialite'
    if ::File.exist?(config_['database'])
      $stderr.puts "#{config_['database']} already exists"
    else
      begin
        # Create the SQLite database
        ::ActiveRecord::Base.establish_connection(config_)
        conn_ = ::ActiveRecord::Base.connection
        conn_.execute('SELECT InitSpatialMetaData()')
      rescue ::Exception => e_
        $stderr.puts e_, *(e_.backtrace)
        $stderr.puts "Couldn't create database for #{config_.inspect}"
      end
    end
  else
    create_database_without_spatialite(config_)
  end
end


def drop_database(config_)
  if config_['adapter'] == 'spatialite'
    require 'pathname'
    path_ = ::Pathname.new(config_['database'])
    file_ = path_.absolute? ? path_.to_s : ::File.join(::Rails.root, path_)
    ::FileUtils.rm(file_)
  else
    drop_database_without_spatialite(config_)
  end
end


::RGeo::ActiveRecord::TaskHacker.modify('db:charset', nil, 'spatialite') do |config_|
  ::ActiveRecord::Base.establish_connection(config_)
  puts(::ActiveRecord::Base.connection.encoding)
end


::RGeo::ActiveRecord::TaskHacker.modify('db:structure:dump', nil, 'spatialite') do |config_|
  dbfile_ = config_["database"] || config_["dbfile"]
  `sqlite3 #{dbfile_} .schema > db/#{::Rails.env}_structure.sql`
end


::RGeo::ActiveRecord::TaskHacker.modify('db:test:clone_structure', 'test', 'spatialite') do |config_|
  dbfile_ = config_["database"] || config_["dbfile"]
  `sqlite3 #{dbfile_} < #{::Rails.root}/db/#{::Rails.env}_structure.sql`
end


::RGeo::ActiveRecord::TaskHacker.modify('db:test:purge', 'test', 'spatialite') do |config_|
  dbfile_ = config_["database"] || config_["dbfile"]
  ::File.delete(dbfile_) if ::File.exist?(dbfile_)
  create_database(config_)
end

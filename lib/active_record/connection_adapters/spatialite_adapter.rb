# -----------------------------------------------------------------------------
# 
# SpatiaLite adapter for ActiveRecord
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


require 'rgeo/active_record'
require 'active_record/connection_adapters/sqlite3_adapter'


# The activerecord-spatialite-adapter gem installs the *spatialite*
# connection adapter into ActiveRecord.

module ActiveRecord
  
  
  # ActiveRecord looks for the spatialite_connection factory method in
  # this class.
  
  class Base
    
    
    # Create a spatialite connection adapter.
    
    def self.spatialite_connection(config_)
      unless 'spatialite' == config_[:adapter]
        raise ::ArgumentError, 'adapter name should be "spatialite"'
      end
      unless config_[:database]
        raise ::ArgumentError, "No database file specified. Missing argument: database"
      end
      
      # Allow database path relative to Rails.root, but only if
      # the database path is not the special path that tells
      # Sqlite to build a database only in memory.
      if defined?(::Rails.root) && ':memory:' != config_[:database]
        config_[:database] = ::File.expand_path(config_[:database], ::Rails.root)
      end
      
      unless self.class.const_defined?(:SQLite3)
        require_library_or_gem('sqlite3')
      end
      db_ = ::SQLite3::Database.new(config_[:database], :results_as_hash => true)
      db_.busy_timeout(config_[:timeout]) unless config_[:timeout].nil?
      
      # Load SpatiaLite
      path_ = config_[:libspatialite]
      if path_ && (!::File.file?(path_) || !::File.readable?(path_))
        raise "Cannot read libspatialite library at #{path_}"
      end
      unless path_
        prefixes_ = ['/usr/local/spatialite', '/usr/local/libspatialite', '/usr/local', '/opt/local', '/sw/local', '/usr']
        suffixes_ = ['so', 'dylib'].join(',')
        prefixes_.each do |prefix_|
          pa_ = ::Dir.glob("#{prefix_}/lib/libspatialite.{#{suffixes_}}")
          if pa_.size > 0
            path_ = pa_.first
            break
          end
        end
      end
      unless path_
        raise 'Cannot find libspatialite in the usual places. Please provide the path in the "libspatialite" config parameter.'
      end
      db_.enable_load_extension(1)
      db_.load_extension(path_)
      
      ::ActiveRecord::ConnectionAdapters::SpatiaLiteAdapter::MainAdapter.new(db_, logger, config_)
    end
    
    
  end
  
  
  # All ActiveRecord adapters go in this namespace.
  module ConnectionAdapters
    
    # The SpatiaLite Adapter
    module SpatiaLiteAdapter
      
      # The name returned by the adapter_name method of this adapter.
      ADAPTER_NAME = 'SpatiaLite'.freeze
      
    end
    
  end
  
  
end


require 'active_record/connection_adapters/spatialite_adapter/version.rb'
require 'active_record/connection_adapters/spatialite_adapter/native_format_parser.rb'
require 'active_record/connection_adapters/spatialite_adapter/main_adapter.rb'
require 'active_record/connection_adapters/spatialite_adapter/spatial_table_definition.rb'
require 'active_record/connection_adapters/spatialite_adapter/spatial_column.rb'
require 'active_record/connection_adapters/spatialite_adapter/arel_tosql.rb'


ignore_tables_ = ::ActiveRecord::SchemaDumper.ignore_tables
ignore_tables_ << 'geometry_columns' unless ignore_tables_.include?('geometry_columns')
ignore_tables_ << 'geometry_columns_auth' unless ignore_tables_.include?('geometry_columns_auth')
ignore_tables_ << 'views_geometry_columns' unless ignore_tables_.include?('views_geometry_columns')
ignore_tables_ << 'virts_geometry_columns' unless ignore_tables_.include?('virts_geometry_columns')
ignore_tables_ << 'spatial_ref_sys' unless ignore_tables_.include?('spatial_ref_sys')
ignore_tables_ << /^idx_\w+_\w+$/ unless ignore_tables_.include?(/^idx_\w+_\w+$/)

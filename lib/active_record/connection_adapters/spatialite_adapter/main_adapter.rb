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


module ActiveRecord
  
  module ConnectionAdapters
    
    module SpatiaLiteAdapter
      
      
      class MainAdapter < SQLite3Adapter
        
        
        ADAPTER_NAME = 'SpatiaLite'.freeze
        
        @@native_database_types = nil
        
        
        def adapter_name
          ADAPTER_NAME
        end
        
        
        def spatial_column_constructor(name_)
          ::RGeo::ActiveRecord::DEFAULT_SPATIAL_COLUMN_CONSTRUCTORS[name_]
        end
        
        
        def native_database_types
          @@native_database_types ||= super.merge(:spatial => {:name => 'geometry'})
        end
        
        
        def spatialite_version
          @spatialite_version ||= SQLiteAdapter::Version.new(select_value('SELECT spatialite_version()'))
        end
        
        
        def srs_database_columns
          {:name_column => 'ref_sys_name', :proj4text_column => 'proj4text', :auth_name_column => 'auth_name', :auth_srid_column => 'auth_srid'}
        end
        
        
        def quote(value_, column_=nil)
          if ::RGeo::Feature::Geometry.check_type(value_)
            "GeomFromWKB(X'#{::RGeo::WKRep::WKBGenerator.new(:hex_format => true).generate(value_)}', #{value_.srid})"
          else
            super
          end
        end
        
        
        def columns(table_name_, name_=nil)  #:nodoc:
          spatial_info_ = spatial_column_info(table_name_)
          table_structure(table_name_).map do |field_|
            col_ = SpatialColumn.new(field_['name'], field_['dflt_value'], field_['type'], field_['notnull'].to_i == 0)
            info_ = spatial_info_[field_['name']]
            if info_
              col_.set_srid(info_[:srid])
            end
            col_
          end
        end
        
        
        def indexes(table_name_, name_=nil)
          results_ = super.map do |index_|
            ::RGeo::ActiveRecord::SpatialIndexDefinition.new(index_.table, index_.name, index_.unique, index_.columns, index_.lengths)
          end
          table_name_ = table_name_.to_s
          names_ = select_values("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'idx_#{quote_string(table_name_)}_%' AND rootpage=0") || []
          results_ + names_.map do |n_|
            col_name_ = n_.sub("idx_#{table_name_}_", '')
            ::RGeo::ActiveRecord::SpatialIndexDefinition.new(table_name_, n_, false, [col_name_], [], true)
          end
        end
        
        
        def create_table(table_name_, options_={})
          table_name_ = table_name_.to_s
          table_definition_ = SpatialTableDefinition.new(self)
          table_definition_.primary_key(options_[:primary_key] || ::ActiveRecord::Base.get_primary_key(table_name_.singularize)) unless options_[:id] == false
          yield table_definition_ if block_given?
          if options_[:force] && table_exists?(table_name_)
            drop_table(table_name_, options_)
          end
          
          create_sql_ = "CREATE#{' TEMPORARY' if options_[:temporary]} TABLE "
          create_sql_ << "#{quote_table_name(table_name_)} ("
          create_sql_ << table_definition_.to_sql
          create_sql_ << ") #{options_[:options]}"
          execute create_sql_
          
          table_definition_.spatial_columns.each do |col_|
            execute("SELECT AddGeometryColumn('#{quote_string(table_name_)}', '#{quote_string(col_.name.to_s)}', #{col_.srid}, '#{quote_string(col_.spatial_type.gsub('_','').upcase)}', 'XY', #{col_.null ? 0 : 1})")
          end
        end
        
        
        def drop_table(table_name_, options_={})
          indexes(table_name_).each do |index_|
            remove_index(table_name_, :spatial => true, :column => index_.columns[0]) if index_.spatial
          end
          execute("DELETE from geometry_columns where f_table_name='#{quote_string(table_name_.to_s)}'")
          super
        end
        
        
        def add_column(table_name_, column_name_, type_, options_={})
          if (info_ = spatial_column_constructor(type_.to_sym))
            limit_ = options_[:limit]
            options_.merge!(limit_) if limit_.is_a?(::Hash)
            type_ = (options_[:type] || info_[:type] || type_).to_s.gsub('_', '').upcase
            execute("SELECT AddGeometryColumn('#{quote_string(table_name_.to_s)}', '#{quote_string(column_name_.to_s)}', #{options_[:srid].to_i}, '#{quote_string(type_.to_s)}', 'XY', #{options_[:null] == false ? 0 : 1})")
          else
            super
          end
        end
        
        
        def add_index(table_name_, column_name_, options_={})
          if options_[:spatial]
            column_name_ = column_name_.first if column_name_.kind_of?(::Array) && column_name_.size == 1
            table_name_ = table_name_.to_s
            column_name_ = column_name_.to_s
            spatial_info_ = spatial_column_info(table_name_)
            unless spatial_info_[column_name_]
              raise ::ArgumentError, "Can't create spatial index because column '#{column_name_}' in table '#{table_name_}' is not a geometry column"
            end
            result_ = select_value("SELECT CreateSpatialIndex('#{quote_string(table_name_)}', '#{quote_string(column_name_)}')").to_i
            if result_ == 0
              raise ::ArgumentError, "Spatial index already exists on table '#{table_name_}', column '#{column_name_}'"
            end
            result_
          else
            super
          end
        end
        
        
        def remove_index(table_name_, options_={})
          if options_[:spatial]
            table_name_ = table_name_.to_s
            column_ = options_[:column]
            if column_
              column_ = column_[0] if column_.kind_of?(::Array)
              column_ = column_.to_s
            else
              index_name_ = options_[:name]
              unless index_name_
                raise ::ArgumentError, "You need to specify a column or index name to remove a spatial index."
              end
              if index_name_ =~ /^idx_#{table_name_}_(\w+)$/
                column_ = $1
              else
                raise ::ArgumentError, "Unknown spatial index name: #{index_name_.inspect}."
              end
            end
            spatial_info_ = spatial_column_info(table_name_)
            unless spatial_info_[column_]
              raise ::ArgumentError, "Can't remove spatial index because column '#{column_}' in table '#{table_name_}' is not a geometry column"
            end
            index_name_ = "idx_#{table_name_}_#{column_}"
            has_index_ = select_value("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='#{quote_string(index_name_)}'").to_i > 0
            unless has_index_
              raise ::ArgumentError, "Spatial index not present on table '#{table_name_}', column '#{column_}'"
            end
            execute("SELECT DisableSpatialIndex('#{quote_string(table_name_)}', '#{quote_string(column_)}')")
            execute("DROP TABLE #{quote_table_name(index_name_)}")
          else
            super
          end
        end
        
        
        def spatial_column_info(table_name_)
          info_ = execute("SELECT * FROM geometry_columns WHERE f_table_name='#{quote_string(table_name_.to_s)}'")
          result_ = {}
          info_.each do |row_|
            result_[row_['f_geometry_column']] = {
              :name => row_['f_geometry_column'],
              :type => row_['type'],
              :dimension => row_['coord_dimension'],
              :srid => row_['srid'],
              :has_index => row_['spatial_index_enabled'],
            }
          end
          result_
        end
        
        
      end
      
      
    end
    
  end
  
end

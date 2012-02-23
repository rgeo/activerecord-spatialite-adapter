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


# :stopdoc:

module ActiveRecord

  module ConnectionAdapters

    module SpatiaLiteAdapter


      class SpatialTableDefinition < ConnectionAdapters::TableDefinition

        def column(name_, type_, options_={})
          if (info_ = @base.spatial_column_constructor(type_.to_sym))
            options_[:type] ||= info_[:type] || type_
            type_ = :spatial
          end
          super(name_, type_, options_)
          if type_ == :spatial
            col_ = self[name_]
            col_.extend(SpatialColumnDefinitionMethods) unless col_.respond_to?(:srid)
            options_.merge!(col_.limit) if col_.limit.is_a?(::Hash)
            col_.set_spatial_type(options_[:type])
            col_.set_srid(options_[:srid].to_i)
          end
          self
        end

        def to_sql
          @columns.find_all{ |c_| !c_.respond_to?(:srid) }.map{ |c_| c_.to_sql } * ', '
        end

        def spatial_columns
          @columns.find_all{ |c_| c_.respond_to?(:srid) }
        end

      end


      module SpatialColumnDefinitionMethods  # :nodoc:

        def spatial_type
          defined?(@spatial_type) && @spatial_type
        end

        def srid
          defined?(@srid) ? @srid : 4326
        end

        def set_spatial_type(value_)
          @spatial_type = value_.to_s
        end

        def set_srid(value_)
          @srid = value_
        end

      end


    end

  end

end

# :startdoc:

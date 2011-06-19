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
      
      
      # A utility class that parses the native (internal) SpatiaLite
      # format. This is used to read and return an attribute value as an
      # RGeo object.
      
      class NativeFormatParser
        
        
        # Create a parser that generates features using the given factory.
        
        def initialize(factory_)
          @factory = factory_
        end
        
        
        # Parse the given binary data and return an object.
        # Raises ::RGeo::Error::ParseError on failure.
        
        def parse(data_)
          if data_[0,1] =~ /[0-9a-fA-F]/
            data_ = [data_].pack('H*')
          end
          @little_endian = data_[1,1] == "\x01"
          srid_ = data_[2,4].unpack(@little_endian ? 'V' : 'N').first
          begin
            _start_scanner(data_)
            obj_ = _parse_object(false)
            _get_byte(0xfe)
          ensure
            _clean_scanner
          end
          obj_
        end
        
        
        def _parse_object(contained_)  # :nodoc:
          _get_byte(contained_ ? 0x69 : 0x7c)
          type_code_ = _get_integer
          case type_code_
          when 1
            coords_ = _get_doubles(2)
            @factory.point(*coords_)
          when 2
            _parse_line_string
          when 3
            interior_rings_ = (1.._get_integer).map{ _parse_line_string }
            exterior_ring_ = interior_rings_.shift || @factory.linear_ring([])
            @factory.polygon(exterior_ring_, interior_rings_)
          when 4
            @factory.multi_point((1.._get_integer).map{ _parse_object(1) })
          when 5
            @factory.multi_line_string((1.._get_integer).map{ _parse_object(2) })
          when 6
            @factory.multi_polygon((1.._get_integer).map{ _parse_object(3) })
          when 7
            @factory.collection((1.._get_integer).map{ _parse_object(true) })
          else
            raise ::RGeo::Error::ParseError, "Unknown type value: #{type_code_}."
          end
        end
        
        
        def _parse_line_string  # :nodoc:
          count_ = _get_integer
          coords_ = _get_doubles(2 * count_)
          @factory.line_string((0...count_).map{ |i_| @factory.point(*coords_[2*i_,2]) })
        end
        
        
        def _start_scanner(data_)  # :nodoc:
          @_data = data_
          @_len = data_.length
          @_pos = 38
        end
        
        
        def _clean_scanner  # :nodoc:
          @_data = nil
        end
        
        
        def _get_byte(expect_=nil)  # :nodoc:
          if @_pos + 1 > @_len
            raise ::RGeo::Error::ParseError, "Not enough bytes left to fulfill 1 byte"
          end
          str_ = @_data[@_pos, 1]
          @_pos += 1
          val_ = str_.unpack("C").first
          if expect_ && expect_ != val_
            raise ::RGeo::Error::ParseError, "Expected byte 0x#{expect_.to_s(16)} but got 0x#{val_.to_s(16)}"
          end
          val_
        end
        
        
        def _get_integer  # :nodoc:
          if @_pos + 4 > @_len
            raise ::RGeo::Error::ParseError, "Not enough bytes left to fulfill 1 integer"
          end
          str_ = @_data[@_pos, 4]
          @_pos += 4
          str_.unpack("#{@little_endian ? 'V' : 'N'}").first
        end
        
        
        def _get_doubles(count_)  # :nodoc:
          len_ = 8 * count_
          if @_pos + len_ > @_len
            raise ::RGeo::Error::ParseError, "Not enough bytes left to fulfill #{count_} doubles"
          end
          str_ = @_data[@_pos, len_]
          @_pos += len_
          str_.unpack("#{@little_endian ? 'E' : 'G'}*")
        end
        
        
      end
      
      
    end
    
  end
  
end

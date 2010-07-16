##############################################################
# FONTUE - THE OPEN SOURCE WEB FONT SERVER v19042010
##############################################################
#
# Fontue is a Rack-based, open-source, 
# web font server built for Kernest.com
#
# For the latest version of this code visit: 
# http://github.com/garrickvanburen/fontue
#
# For more information about Rack: 
# http://rack.rubyforge.org/
#
# Fontue's goals:
#
# - Keep @font-face declarations clean, readable, and cross-browswer compatible.
#
# - Serve the appropriate font format (otf/ttf, eot, svg, or woff) to browsers supporting @font-face.
#
# - Save bandwidth by effectively setting cache headers.
#
# - Save bandwidth by not sending fonts to user agents that don't 
#   support @font-face.
#
# - Save bandwidth by not sending fonts to requests that shouldn't 
#   receive the font (domain checking).
#
# - Serve fonts really fast.
#
##############################################################
#
# FONTUE ASSUMES THE FOLLOWING @font-face { src: } SYNTAX
#
# @font-face {
#	...
#	src: url('http://woffly.com/font/FONT_FILENAME_WITHOUT_FORMAT'), url('http://woffly.com/font/FONT_FILENAME_WITHOUT_FORMAT#SVG_FONT_ID') format('svg');
# }
#
##############################################################
#
# TO INSTALL AND RUN FONTUE
#
# 1. Create a directory on your server for your web fonts. And update the font_server_directory variable in line 93. Default is '/fonts'.
#
# 2. Upload your web fonts into a directory to your server - say '/fonts' 
#    - Safari, Chrome, Firefox, and Opera like .otf & .ttf fonts
#    - Mobile Safari and early versions of Chrome prefer .svg fonts
#    - Later versions of Firefox also like .woff fonts
#
# 3. Upload fontue.ru to your server
#    Depending on the server you're using, you may also need a config.yml file.
#
# 4. Configure your Rack-compliant web server (i.e. Thin, Ebb, Lighttpd, etc) and Run: rackup fontue.ru
#    Fontue can also be easily adapted for use as an endpoint within Ruby on Rails' Metal.
#
# 5. Fontue will now be accepting requests on your server at: /font (change this in line 189)
#
##############################################################
#
# Copyright (c) 2010 Garrick Van Buren, Working Pathways, Inc.
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
##############################################################

require 'rubygems'
require 'rack'
require 'time'
require "digest/sha1"

fontue = proc do |env|
  
  # THE ABSOLUTE PATH TO WHERE THE FONTS LIVE
  font_server_directory = '/fonts'

  # DON'T SERVE FONTS TO REQUESTS WITHOUT A REFERER OR USER AGENT 
  return [417, {"Content-Type" => "text/html"}, ["Expectation Failed"]] unless (env['HTTP_REFERER'] && env['HTTP_USER_AGENT'])

  #
  # IF YOU'RE DOING BLANKET DOMAIN CHECKING, 
  # ENTER A REGEX OF THE AUTHORIZED DOMAINS
  # AND UNCOMMENT THE NEXT 2 LINES
  #
  # authorized_domains = /...AUTHORIZED_DOMAIN.../
  # return [417, {"Content-Type" => "text/html"}, ["Expectation Failed"]] unless env['HTTP_REFERER'].match(authorized_domains)
  #
  
  # DON'T SERVE FONTS TO UNSUPPORTED BROWSERS
  supported_browsers = /Chrome\/[3-9]|Firefox\/[3-9]|\sMSIE\s|Konqueror\/[4-9]|Midori|Minefield|Shiretoko|IceCat|Opera\/9.|\sAppleWebKit/
  return [417, {"Content-Type" => "text/html"}, ["Expectation Failed Bad Agent"]] unless env['HTTP_USER_AGENT'].match(supported_browsers)

  slug = env["PATH_INFO"].split('/')[1] 
  return [400, {"Content-Type" => "text/html"}, ["Bad Request"]] unless slug

  # GET THE FONT SLUG FROM THE REQUEST
  # FONTUE ASSUMES THE FOLLOWING @font-face { src: } SYNTAX
  #
  # @font-face {
  #	...
  #	src: url('http://woffly.com/font/FONT_FILENAME_WITHOUT_FORMAT'), url('http://woffly.com/font/FONT_FILENAME_WITHOUT_FORMAT#SVG_FONT_ID') format('svg');
  # }
  #
  # THIS FUNNY SPLIT IS FOR INTERNET EXPLORER - IT DOESN'T STOP READING AT THE COMMA
  # TO DO: FIGURE OUT WHY SOME RACK SERVERS PREFER THE REGEX AND WHY OTHERS PREFER THE STRING
  #slug     = slug.split(/\'\),\surl\(\'/)[0]     
  slug = slug.split("'),%20url('")[0]
       
  # GRAB THE BROWSER APPROPRIATE FORMAT
  woff_browsers      = /Firefox\/[3-9]|Konqueror\/[4-9]/
  eot_browsers       = /\sMSIE\s/
  svg_browsers       = /\s\(iP|Chrome\/3|Presto\/(\d+.)*\d+$/

  format = if env['HTTP_USER_AGENT'].match(svg_browsers)
            "svg"
           elsif env['HTTP_USER_AGENT'].match(eot_browsers)
            "eot"
           elsif env['HTTP_USER_AGENT'].match(woff_browsers)
            "woff"
           else
             File.exists?(font_server_directory + "/" + slug + ".otf") ? "otf" : "ttf"
           end
    
  # DOES THE BROWSER ACCEPT GZIPPING? DON'T SEND GZIPPED WOFFS OR SVGS, IT DOESN'T HELP AND IT ANNOYS BOTH FIREFOX & MOBILE SAFARI
  accepts_gzip = (env['HTTP_ACCEPT_ENCODING'] && env['HTTP_ACCEPT_ENCODING'].match(/gzip/) && !format.match(/woff|svg/) ) ? ".jgz" : ""

  # BUILD THE PATH TO THE FONT
  font_url = "/" + slug + "." + format + accepts_gzip
  
  # RESET THE ENV PATHS TO THE FULL PATH TO THE FONT
  env["PATH_INFO"]   = font_url
  env["REQUEST_URI"] = font_url
  
  # GRAB THE FONT OUT OF THE FONT SERVER DIRECTORY
  file_server = Rack::File.new(font_server_directory)
  status, headers, body = file_server.call(env)
  
  # SET THE ETAG
  etag = Digest::SHA1.hexdigest("#{headers['Last-Modified']}#{headers['Content-Length']}")
    
  # CHECK IF THE FONT NEEDS TO BE SENT. IF SO - SEND IT & CACHE IT ON THE CLIENT FOR 1 YEAR.
  if (etag == env['HTTP_IF_NONE_MATCH'] || headers['Last-Modified'] == env['HTTP_IF_MODIFIED_SINCE'])
     status = 304
     headers.delete('Content-Type')
     headers.delete('Content-Length')
     body = [] 
     
  else
    content_type = if format.match('svg') 
                      "image/svg+xml"
                    else
                      "applications/octet-stream "
                    end
    
    one_year_of_seconds = (60 * 60 * 24 * 365)
                    
    headers['Content-Type']                 = content_type    
    headers['Content-Encoding']             = "gzip" unless accepts_gzip.empty?
    headers['Content-Disposition']          = "inline,filename='" + slug + "." + format  + accepts_gzip +"'"
    headers['Cache-Control']                = "max-age=" + one_year_of_seconds.to_s + ",public"
    headers['Access-Control-Allow-Origin']  = "*"
    headers['Expires']                      = (Time.new + one_year_of_seconds).rfc822
    headers['ETag']                         = etag
   end
  
  [status, headers, body]                 
end



map '/font' do
  run fontue
end
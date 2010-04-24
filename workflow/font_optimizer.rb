#########################################################
# FONTUE FONT OPTIMIZER WORKFLOW v19042010
#########################################################
#
# The Fontue Font Optimizer Workflow is a Ruby script for quickly 
# optimizing fonts for browser-based @font-face use.
# 
# This script is basically a wrapper tying together other
# command-line font optimization tools including;
# 
# - FontForge: http://fontforge.sourceforge.net
#
# - sfnt2woff: http://people.mozilla.com/~jkew/woff
#
# - Batik: http://xmlgraphics.apache.org/batik
#
# - EOTFast: http://eotfast.com
#
#
# Fontue Font Optimizer Workflow goals:
# - Simplify the generation and optimization of fonts for web use.
# - Run via the command line
#
# This script can be used to generate the fonts served by Fontue.
##############################################################
#
# TO INSTALL AND RUN FONTUE FONT OPTIMIZER
#
# 1. Download and install FontForge, sfnt2woff, Batik, and EOTFast.
#    They don't need to all be on the same machine, they're not in my world. 
#
# 2. Update the fonts_dir, eot_dir, sfnt2woff_dir, and batik_dir paths to reflect 
#    your configuration.
#    TO DO: Remove the need to set these explicitly. 
#
# 3. Make a copy of the fonts directory you'll be optimizing.
#    This script will write over any existing TTFs and OTFs. 
#    Make a copy of the fonts directory you'll be optimizing.
#
# 4. Run the script using: ruby font_optimizer.rb
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


fonts_dir     = "/DIRECTORY/OF/FONTS/TO/CONVERT"
eot_dir       = "/DESTINATION/FOR/TTFS/FOR/EOTFAST/CONVERSION"
sfnt2woff_dir = "/PATH/TO/SFNT2WOFF"
batik_dir     = "/PATH/TO/BATIK"


##############################################################
## 1. HAVE FONTFORGE CLEAN UP THE TABLES (MAINLY FOR WINDOWS) 
## AND GENERATE THE INITIAL FONTS. 
## FONTFORGE IS PRETTY RESOURCE INTENSIVE
## THIS CAN TAKE A WHILE. BE PATIENT.  
##############################################################
fonts = Dir.new(fonts_dir).entries
fonts.each do |font|
  font = "#{fonts_dir}/#{font}"
	%x{fontforge -script fontforge_font_optimizer.pe #{font}}
end
##############################################################


##############################################################
## 2. SELECT ALL THE FONTS 
## AND GENERATE WOFFs USING THE SFNT2WOFF TOOL
##############################################################
fonts = Dir.new(fonts_dir).entries
fonts.each do |font|
  font = "#{fonts_dir}/#{font}"
  %x{#{sfnt2woff}/sfnt2woff #{font} }
end
##############################################################

##############################################################
## 3. SELECT ALL THE TTFs 
## AND GENERATE SVGs USING BATIK'S TTF2SVG TOOL
##############################################################
fonts = Dir.new(fonts_dir).entries.grep(/\.ttf$/)
fonts.each do |font|
  font.gsub!('.ttf', '')
  ttf =  "#{fonts_dir}/#{font}.ttf"
  svg =  "#{fonts_dir}/#{font}.svg"    
  %x{java -jar #{batik_dir}/batik-ttf2svg.jar #{ttf} -o #{svg} -id #{id} }

  # NOW COPY THE TTF TO THE EOT DIRECTORY FOR EOT CONVERSIONS
  %x{cp #{ttf} #{eot_dir} } 
end
##############################################################

##############################################################
# 4. GENERATE THE EOTFAST FILES 
# USE THIS BATCH COMMAND TO CONVERT TTFS TO EOTS VIA THE COMMAND 
# LINE WITH EOTFAST. 
# RUN IT FROM DIR CONTAINING EOTFAST-1.EXE
# YOU MAY NEED TO REPLACE 'EOT_DIR' WITH THE FULL PATH TO THE EOT
# DIRECTORY
#
# TO DO: FIND A WAY TO AUTOMATE THIS STEP FROM WITHIN THIS SCRIPT
###
# FOR %X IN ("C:\EOT_DIR") DO EOTFAST-1.EXE "%X"
###
##############################################################

##############################################################
# 5. COPY THE NEW EOTs BACK TO FONTS DIRECTORY
##############################################################
fonts = Dir.new(eot_dir).entries.grep(/.eot$/)
fonts.each do |font|
    eot = "#{eot_dir}/#{font}"
    %x{cp #{eot} #{fonts_dir} } 
end
##############################################################

##############################################################
# 6. CREATE GZIP VERSIONS OF ALL THE FONTS
# WE'RE NOT GOING TO USE THE GZIPPED WOFFS & SVGS
# BUT WE'LL GZIP THEM ANYWAY BECAUSE IT'S SIMPLER CODE
##############################################################
fonts = Dir.new(fonts_dir).entries
fonts.each do |font|
  font = "#{fonts_dir}/#{font}"
  %x{gzip -c #{font} > #{font}.jgz}
end
##############################################################
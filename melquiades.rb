#!/usr/bin/env ruby

# Copyright 2012 Rafael Martins
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'rubygems'
require 'json'
require 'open-uri'

DEBUG_SKIP_GIT_UPDATE = false
DEBUG_SKIP_SVN_UPDATE = false
DEBUG_SKIP_JSON_UPDATE = true

base_url = 'http://melquiades.flossmetrics.org'

blacklist = []
File.open('blacklist').each_line do |line|
  blacklist << line.chomp
end

projects_dir = "#{Dir.pwd}/projects"
begin
  Dir.mkdir(projects_dir)
rescue
  puts "Warning: '#{projects_dir}' already exists."
end

if File.exists? "#{projects_dir}/00_list.json"
  projects_json = File.open("#{projects_dir}/00_list.json").read
end
if DEBUG_SKIP_JSON_UPDATE == false
  print "Getting project list... "
  begin
    projects_json = URI.parse("#{base_url}/projects.json").read
    File.open("#{projects_dir}/00_list.json", 'w') { |f| f.write(projects_json) }
    puts "OK"
  rescue Exception => e
    puts "Not ok!"
    puts e.message  
  end
end

DEBUG_MAX_PROJECT = 1
proj_count = 0
JSON(projects_json).each do |project|
  proj_count = proj_count + 1
  break if proj_count > DEBUG_MAX_PROJECT

  puts "[#{project['name']}]"

  if blacklist.include? project['name']
    puts "Blacklisted!"
    next
  end

  project_path = projects_dir + '/' + project['name']
  begin
    Dir.mkdir(project_path)
  rescue
    puts "Warning: '#{project_path}' already exists."
  end

  if DEBUG_SKIP_JSON_UPDATE == false
    print "Getting info (.json)... "
    begin
      info_url = base_url + project['url'] + '.json'
      info_json = URI.parse(info_url).read
      File.open(project_path + '/info.json', 'w') {|f| f.write(info_json)}
      puts "OK"
    rescue Exception => e
      puts "Not ok!"
      puts e.message  
      puts e.backtrace.inspect 	
    end

    puts "Getting dumps (.json)..."
    begin
      dumps_url = base_url + project['url'] + '/dumps.json'
      dumps_json = URI.parse(dumps_url).read
      File.open(project_path + '/dumps.json', 'w') {|f| f.write(dumps_json)}
      JSON(dumps_json).each do |dump|
        filename = File.basename(dump['dump_url'])
        puts '  ' + filename
        File.open(project_path + '/' + filename, 'w') do |f|      
          f.write(URI.parse(dump['dump_url']).read)
        end    
      end
      puts "OK"
    rescue Exception => e
      puts "Not ok!"
      puts e.message  
      puts e.backtrace.inspect 	
    end

    print "Getting resources (.json)... "
    begin
      resources_url = base_url + project['url'] + '/resources.json'
      resources_json = URI.parse(resources_url).read
      File.open(project_path + '/resources.json', 'w') {|f| f.write(resources_json)}
      puts "OK"
    rescue Exception => e
      puts "Not ok!"
      puts e.message  
      puts e.backtrace.inspect 	
    end
  end

  print "Checking available SCM's..."
  File.open(project_path + '/resources.json', 'r') do |f|
    resources_json = JSON(f.read)
  end
  scm = nil
  resources_json.each do |resource|
    if resource['name'] == 'SCM Repository'
      if scm.nil? or scm['type'] == 'cvs'
        scm = resource
      elsif scm['type'] == 'svn' and resource['type'] == 'git'
        scm = resource
      end
    end
  end
  puts " Priority: #{scm['type']}"

  puts "Checking out code..."
  begin
    if scm['type'] == 'git'
      git_path = project_path + '/git'
      git_url = scm['url']
      # There's a problem with Sourceforge git url's
      if git_url.include? 'sourceforge'
        name = git_url.split('/').last
        git_url = "#{git_url}/#{name}"
      end			
      # Check if it was already downloaded; if yes, just update
      git_dirs = `ls -d #{git_path} 2>/dev/null`
      if !git_dirs.empty?
        next if DEBUG_SKIP_GIT_UPDATE
        git_path = git_dirs.split("\n").first
        git_cmd = "cd #{git_path} && git fetch origin && git pull origin master"
        puts "  GIT Fetch/Pull: #{git_url}"
      else
        git_cmd = "git clone #{git_url} #{git_path}"
        puts "  GIT Clone: #{git_url}"
      end
      `#{git_cmd}`
    end

    if scm['type'] == 'svn'
      svn_url = scm['url']
      svn_path = project_path + '/svn'
      # Check if was already downloaded; if so, just update
      svn_dirs = `ls -d #{svn_path} 2>/dev/null`
      if !svn_dirs.empty?
        next if DEBUG_SKIP_SVN_UPDATE
        svn_path = svn_dirs.split("\n")[0]
        svn_cmd = "cd #{svn_path} && svn update"
        puts "  SVN Update: #{svn_url}"
      else
        `svn list #{svn_url}`.each_line do |line|
          if line.downcase.chomp == 'trunk/'
            svn_url = svn_url + '/trunk'
            svn_path = svn_path + '_trunk'
          end
        end
        begin
          Dir.mkdir(svn_path)
        rescue
          puts "  Warning: #{svn_path} already exists."
        end
        svn_cmd = "svn checkout #{svn_url} #{svn_path}"
        puts "  SVN Checkout: #{svn_url}"
      end
      `#{svn_cmd}` 
    end        

    #      if resource['type'] == 'cvs'
    #        cvs_url = resource['url']
    #        cvs_url.gsub!('anonymous', 'anonymous:')
    #        puts `cvs -d #{cvs_url} login` 
    #        if $? == 0
    #          modules = `cvs -d #{cvs_url} checkout -c`.split
    #          if !modules.empty?
    #            
    #            exit
    #          end
    #        end
    #      end
    puts "OK"
  rescue Exception => e
    puts "Not ok!"
    puts e.message  
    puts e.backtrace.inspect 	
    exit
  end

  #  break
end

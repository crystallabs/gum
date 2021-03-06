require "logger"
require "yaml"
require "option_parser"
require "./gum/*"

module Gum
	class Config
		YAML.mapping(
			config_file: { type: String, nilable: false, default: File.join ENV["HOME"], ".config", "gum", "gumrc"},
			basedir: { type: String, nilable: false, default: File.join ENV["HOME"], "gum"},
			repositories: { type: Hash(String,Array(String)), nilable: false, default: {} of String =>Array(String)},
			prefix: { type: String, nilable: false, default: "gum_local-"},
			logfile: { type: String, nilable: false, default: "STDOUT"},
			loglevel: { type: String, nilable: false, default: "info"},
			update_remote: { type: Bool, nilable: false, default: true},
			update_local: { type: Bool, nilable: false, default: false},
			show_remote_pulls: { type: Bool, nilable: false, default: true},
			show_local_pulls: { type: Bool, nilable: false, default: false},
			show_diffs: { type: Bool, nilable: false, default: true},
			write_config: { type: Bool, nilable: false, default: false},
		)

		def self.load!
			dir = File.join ENV["HOME"], ".config", "gum"
			config_file = File.join dir, "gumrc"
			Dir.mkdir_p dir
			if File.exists? config_file
				Config.from_yaml File.read config_file
			else
				config = Config.from_yaml ""
				File.write config_file, config.to_yaml
				config
			end
		end
	end

	class Engine
		@logger : Logger

		def initialize
			@config = Gum::Config.load!

			# Just temporary initialization, then set more user-controlled value
			@logger = Logger.new File.new "/dev/null"
			set_logger

			@logger.debug "Ensuring base directory for repositories is present: #{@config.basedir}"
			Dir.mkdir_p @config.basedir
			Dir.cd @config.basedir

			if @config.repositories.size > 0
				@logger.debug %Q(Using repository list from config file: #{@config.repositories.keys.join ", "})
			else
				rs = Dir.glob("*")
				@logger.debug %Q(Taking repository list from existing directories: #{rs.join ", "})
				@config.repositories = rs.each_with_object(["master"]).to_h
			end
		end

		def set_logger
			@logger = l = Logger.new case @config.logfile
				when "STDOUT"
					STDOUT
				when "STDERR"
					STDERR
				else
					File.new @config.logfile
			end

			l.level = Logger::Severity.parse @config.loglevel
    end

		def ensure_branches
			@logger.debug "Ensuring presence of local branches with prefix #{@config.prefix}"
			@config.repositories.each do |r, bs|
				@logger.debug r
				Dir.cd r
				bs.each do |b|
					bn = @config.prefix + b
					`git branch --track #{bn} #{b} >/dev/null 2>&1`
				end
				Dir.cd ".."
			end
		end

		def update_branches(remote = true, local = false)
			@logger.debug "Updating branches, remote: #{remote}, local: #{local}"
			@config.repositories.each do |r, bs|
				@logger.info %Q(*** Repository: #{r}, branches: #{bs.join ", "})
				Dir.cd r
				lbs = bs.map { |b| @config.prefix + b }
				if remote
					bs.each do |b|
						#system "git", ["checkout", b]
						#system "git", ["pull"]
						`git checkout #{b} 2>&1 |grep -v "Already on"`
						output = `git pull |grep -vP "Already up-to-date."`
						puts output if output.size > 0 && @config.show_remote_pulls
					end
				end
				if local
					lbs.each do |b|
						#system "git", ["checkout", b]
						#system "git", ["pull"]
						`git checkout #{b} 2>&1 |grep -v "Already on"`
						output = `git pull |grep -vP "Already up-to-date."`
						puts output if output.size > 0 && @config.show_local_pulls
					end
				end
				Dir.cd ".."
			end
		end

		def show_diffs(rs = @config.repositories)
			@logger.debug %Q(Showing diffs for: #{rs.map {|r, bs| r + ":"+ bs.join ", "}})
			@config.repositories.each do |r, bs|
				@logger.debug r
				Dir.cd r
				# bs
				bs.each do |b|
					lb = @config.prefix + b 
					if @config.show_diffs
						puts "*** Repository: #{r}, branch: #{b}"
						diff = `git log -p #{lb}..#{b}`
						puts diff
					end
				end
				Dir.cd ".."
			end
		end

		def parse_options
			OptionParser.parse! do |parser|
				parser.banner = "Usage: gum [arguments]"

				parser.on("-r", "--remote", "Update remote branches before showing diffs. Default true") { @config.update_remote = true }
				parser.on("-R", "--no-remote", "Do not update remote branches before showing diffs") { @config.update_remote = false }
				parser.on("-l", "--local", "Update local branches after showing diffs. Default false") { @config.update_local = true }
				parser.on("-L", "--no-local", "Do not update local branches after showing diffs") { @config.update_local = false }

				parser.on("-p", "--show-remote-pulls", "Show pulls from remote. Default true") { @config.show_remote_pulls = true }
				parser.on("-P", "--no-show-remote-pulls", "Do not show pulls from remote") { @config.show_remote_pulls = false }
				parser.on("-u", "--show-local-pulls", "Show pull from local. Default false") { @config.show_local_pulls = true }
				parser.on("-U", "--no-show-local-pulls", "Do not show pulls from local") { @config.show_local_pulls = false }

				parser.on("-d", "--diffs", "Show diffs. Default true") { @config.show_diffs = true }
				parser.on("-D", "--no-diffs", "Do not show diffs") { @config.show_diffs = false }

				parser.on("-f", "--logfile FILE", "Log file (STDOUT, STDERR, or filename). Default STDOUT") { |l| @config.logfile = l; set_logger }
				parser.on("-s", "--loglevel LEVEL", "Log level (debug, info, warn, error, fatal, unknown). Default info") { |l| @config.loglevel = l; set_logger }

				parser.on("-w", "--write-config", "Write final config to config file. Default false") { @config.write_config = true }

				parser.on("-h", "--help", "Show this help") { puts parser; exit 0 }

				parser.invalid_option do |flag|
					STDERR.puts "ERROR: #{flag} is not a valid option."
					STDERR.puts parser
					exit(1)
				end
			end
		end

		def write_config
			@logger.info %Q(Writing gum config to #{@config.config_file})
			File.write @config.config_file, @config.to_yaml
		end

		def run
			parse_options

			if @config.write_config
				@config.write_config = false
				write_config
			end

			ensure_branches
			update_branches remote: true, local: false if @config.update_remote
			show_diffs if @config.show_diffs
			update_branches remote: false, local: true  if @config.update_local
		end
	end
end

e = Gum::Engine.new
e.run

module BeEF

#
# This class migrates and updates values in the database each time you restart BeEF.
# So for example, when you want to add a new command module, you stop BeEF, copy your command module into the framework
# and then restart BeEF. That class will take care of installing automatically the new command module in the db.
#
class Migration
  
  include Singleton
  
  #
  # Updates the database.
  #
  def update_db!
    update_commands!
    update_plugins!
  end
  
  #
  # Checks for new command modules and updates the database.
  #
  def update_commands!
    db_commands = [], folders = ''
    
    BeEF::Models::CommandModule.all.each {|db_command| 
      db_commands.push(db_command.path)
    }
    
    Dir.foreach("#{$root_dir}/modules/commands/") do |folder|
      folders += "#{folder}|" if not ['.', '..'].include? folder and File.directory? "#{$root_dir}/modules/commands/#{folder}"
    end
    
    regex = /\/modules\/commands\/(#{folders})\/(.*).rb/i
    
    Dir["#{$root_dir}/modules/commands/**/*.rb"].each do |command|
      if (command = command.match(regex)[0])
        BeEF::Models::CommandModule.new(:path => command, :name => /.*\/(\w+)\.rb/.match(command).to_a[1]).save if not db_commands.include? command
      end
    end

		msf = BeEF::MsfClient.instance
		if(msf.is_enabled && msf.login())
			sploits = msf.browser_exploits()
			sploits.each do |sploit|
				if not BeEF::Models::CommandModule.first(:name => sploit)
					mod = BeEF::Models::CommandModule.new(:path => "Dynamic/Msf", :name => sploit)
					mod.save
					if mod.dynamic_command_info == nil
						msfi = msf.get_exploit_info(sploit)

						st = sploit.split('/').first
						targets = []

						os_name = BeEF::Constants::Os::match_os(st)

						browsers =  BeEF::Constants::Browsers::match_browser(msfi['name'] + msfi['targets'].to_json)

						targets << {'os_name' => os_name, 'browser_name' => 'ALL', 'verified_status' => 2} if browsers.count == 0

						browsers.each do |bn|
							targets << {'os_name' => os_name, 'browser_name' => bn, 'verified_status' => 2}
						end

						msfci = BeEF::Models::DynamicCommandInfo.new(
									:name => msfi['name'],
									:description => msfi['description'],
									:targets => targets.to_json)

						mod.dynamic_command_info = msfci
						mod.save
					end
				end
			end

			payloads = msf.payloads()
			payloads.each do |payload|
				if not  BeEF::Models::DynamicPayloads.first( :name => payload)
					pl = BeEF::Models::DynamicPayloads.new( :name => payload)
					pl.save
					opts = msf.payload_options(payload)
					opts.keys.each do |opt|
						next if opts[opt]['advanced'] or opts[opt]['evasion']
						pl.dynamic_payload_info.new(:name => opt, :description => opts[opt]['desc'], :required => opts[opt]['required'], :value => opts[opt]['default'])
					end
					pl.save
					
				end
			end

		end

  end
  
  #
  # Checks for new plugins and updates the database.
  #
  def update_plugins!
    db_plugins = [], folders = ''

    BeEF::Models::Plugin.all.each {|db_plugin| db_plugins.push(db_plugin.path)}
    
    Dir.foreach("#{$root_dir}/modules/plugins/") do |folder|
      folders += "#{folder}|" if not ['.', '..'].include? folder and File.directory? "#{$root_dir}/modules/plugins/#{folder}"
    end
    
    regex = /\/modules\/plugins\/(#{folders})\/(\w+)\/(\w+).rb/i
    
    Dir["#{$root_dir}/modules/plugins/**/*.rb"].each do |plugin|
      if (plugin = plugin.match(regex)[0])
        BeEF::Models::Plugin.new(:path => plugin).save if not db_plugins.include? plugin
      end
    end
  end

  
end

end

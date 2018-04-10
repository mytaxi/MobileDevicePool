require_relative 'io_stream'
require_relative 'concurrent_runner'

module MobileDevicePool
  class Adb
    class << self
      def restart_server
        cmd = 'adb kill-server && adb start-server'
        result = `#{cmd}`.split("\n").last
        if result.nil?
          return [false, {'message' => 'Error, please try again'}]
        else
          result = result.gsub(/\s?\*\s?/, '')
          if result.include?('success')
            return [true, {'message' => result}]
          else
            return [false, {'message' => result}]
          end
        end
      end
      
      def list_devices
        list = `adb devices`
        devices = list.split("\n").inject([]) do |devices, device|
          device_info = device.split("\t")
          if device_info.size == 2
            devices.push(device_info.first)
          else
            devices
          end
        end
      end
      
      def list_devices_with_details
        devices = list_devices.inject([]) do |devices, device_sn|
          device = {}
          device['sn'] = device_sn
          product_properties = get_properties(device_sn, 'ro.product', *%w(manufacturer brand model))
          os_properties = get_properties(device_sn, 'ro.build.version', *%w(release sdk))
          device.merge!(product_properties).merge!(os_properties)
          device['battery'] = get_battery_level(device_sn)
          info = get_app_info('taxi.android.client.alpha', device_sn)
          if !info.nil?
            device['passengerAppversionAlpha'] = info['versionName']
          else
            device['passengerAppversionAlpha'] = 'null'
          end
          info = get_app_info('taxi.android.client', device_sn)
          if !info.nil?
            device['passengerAppversion'] = info['versionName']
          else
            device['passengerAppversion'] = 'null'
          end
          info = get_app_info('taxi.android.driver.alpha', device_sn)
          if !info.nil?
            device['driverAppversionAlpha'] = info['versionName']
          else
            device['driverAppversionAlpha'] = 'null'
          end
          info = get_app_info('taxi.android.driver', device_sn)
          if !info.nil?
            device['driverAppversion'] = info['versionName']
          else
            device['driverAppversion'] = 'null'
          end
          devices.push(device)
        end
      end

      def writehello
        puts "Threads sind geil"
      end
      
      def list_installed_packages(device_sn = nil)
        cmd = synthesize_command('adb shell pm list packages', device_sn)
        `#{cmd}`.split("\n").map! { |pkg| pkg.gsub(/^package:/, '').chomp }
      end
      
      def take_a_screenshot(dir, device_sn = nil)
        dir = dir.gsub(/\/$/, '') + '/'
        system("mkdir -p #{dir}")
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S_%L')
        file_path = "#{dir}screenshot_#{timestamp}.png"
        cmd = 'adb shell screencap -p'
        cmd = synthesize_command(cmd, device_sn)
        data = `#{cmd}`.encode('ASCII-8BIT', 'binary').gsub(/\r\n/, "\n")
        begin
          File.open(file_path, 'w') { |f| f.write(data) }
        rescue Exception => e
          return [false, {'message' => e.message, 'backtrace' => e.backtrace}]
        end
        return [true, {'file_path' => file_path}]
      end
      
      def get_app_info(package_name = nil, device_sn = nil)
        cmd = synthesize_command("adb shell dumpsys package #{package_name}", device_sn)
        begin
          result = `#{cmd}`.chomp.match(/Packages:(.*|\n?)+\z/)[0].gsub(/Packages:\r?\n/, '').gsub(/^.*Package.*\r?\n/, '')
          info = {}
          number_of_leading_spaces = result.match(/^(\s+)/)[1].size
          result.gsub(/^[^=]+:.*$/, '').gsub(/^[^=:]*$/, '').gsub(/\s+(\w+=)/, '→\1').gsub(/\r?\n/, '').split('→').reject(&:empty?).map(&:chomp).each do |x|
            pair = x.split('=')
            key = pair.first
            value = pair.last
            if value.match(/\[.*\]/)
              info[key] = value.split(/\[|\]|\s|,/).reject(&:empty?)
            else
              info[key] = value
            end
          end
          result.gsub(/\r\n^\s{#{number_of_leading_spaces + 1},}/, ' ').scan(/^\s{#{number_of_leading_spaces}}([^=]*?):\s+(.*)/).each do |x|
            info[x.first] = x.last.chomp.split(/\s+/)
          end
          info
        rescue Exception => e
        end

      end

      def install_app(package_name, device_sn)
          cmd = synthesize_command("adb install -r -d #{package_name}", device_sn)
          result = `#{cmd}`.split("\r\n").last
          if result.match('Failure')
            return false
          end
          return true
      end

      def install_app_multiple_devices(file)
        jobs = list_devices.inject([]) do |result, device_sn|
          job = Proc.new do
            install_app(file, device_sn)
          end
          result.push(job)
        end
        concurrent_runner = ConcurrentRunner.set
        concurrent_runner.set_producer_thread(jobs)
        concurrent_runner.set_consumer_thread
        concurrent_runner.run
      end

      def uninstall_app(package_name, device_sn = nil)
        cmd = synthesize_command("adb uninstall #{package_name}", device_sn)
        result = `#{cmd}`.chomp
        if result == 'Success'
          return true
        elsif result == 'Failure'
          return false
        else
          return false
        end
      end

      def clear_app(package_name, device_sn = nil)
        cmd = synthesize_command("adb shell pm clear #{package_name}", device_sn)
        result = `#{cmd}`.chomp
        if result == 'Success'
          return true
        elsif result == 'Failed'
          return false
        else
          return false
        end
      end

      def input_keyevent(keyevent, device_sn = nil)
        # keyevent should < KeyEvent.getMaxKeyCode()
        if (keyevent.to_i.to_s == keyevent.to_s) && (keyevent.to_i >= 0 && keyevent.to_i <= 221)
          cmd = synthesize_command("adb shell input keyevent #{keyevent}", device_sn)
          `#{cmd}`
          return true
        else
          return false
        end
      end

      def input_text(text, device_sn = nil)
        text = text.gsub(/\s/, '%s')
        cmd = synthesize_command("adb shell input text #{text}", device_sn)
        `#{cmd}`
      end

      def press_power_button(device_sn = nil)
        keycode_power = 26
        input_keyevent(keycode_power, device_sn)
      end

      # Precondition: device needs to be rooted
      def change_language(language, country, device_sn = nil)
        cmd = synthesize_command("adb shell \"su -c 'setprop persist.sys.language #{language}; setprop persist.sys.country #{country}; stop; sleep 5; start'\"", device_sn)
        `#{cmd}`
      end

      def is_device_rooted?(device_sn = nil)
        cmd = synthesize_command("adb shell 'which su; echo $?'", device_sn)
        exit_status = `#{cmd}`.split(/\r\n/)[1].to_i
        return exit_status == 0
      end

      def get_current_activity(device_sn = nil)
        cmd = synthesize_command('adb shell dumpsys activity', device_sn)
        result = `#{cmd}`.chomp.match(/mFocusedActivity:.*?\{[^.]*?((\S+\.)*\S+)[^.]*?\}/i)
        if result
          return result[1]
        else
          return ''
        end
      end

      def open_app_via_deep_link(package_name, deep_link, device_sn = nil)
        cmd = synthesize_command("adb shell am start -W -a android.intent.action.VIEW -d \"#{deep_link}\" #{package_name}", device_sn)
        # exit status is always 0 here
        result = `#{cmd}`.chomp
        if result.match(/^status.*ok/i)
          return [true, {'message' => result.match(/^activity:.*?(([^\s\.]+\.)+[^\s\.]+)/i)[1]}]
        elsif result.match(/^error/i)
          return [false, {'message' => result.match(/^error:\s{0,}(.*)/i)}]
        else
          return false
        end
      end
      
      def get_battery_level(device_sn = nil)
        cmd = synthesize_command('adb shell dumpsys battery | grep level', device_sn)
        result = `#{cmd}`.chomp.match(/\d+$/)
        result ? result[0].to_i : 'N/A'
      end
      
      def start_monkey_test(package_name, device_sn = nil, options = {})
        numbers_of_events = options.fetch(:numbers_of_events, 50000)
        cmd = synthesize_command("adb shell monkey -p #{package_name} -v #{numbers_of_events}", device_sn)
        IoStream.redirect_command_output(cmd) do |line|
          puts line
        end
      end
      
      def stop_monkey_test
        `adb shell ps | awk '/com\.android\.commands\.monkey/ { system("adb shell kill " $2) }'`
      end
      
      def synthesize_command(cmd, device_sn)
        puts "CMD: " + cmd
        if device_sn.nil?
          cmd
        else
          # -s <specific device>
          cmd.gsub(/^adb\s/, "adb -s #{device_sn} ")
        end
      end
      
      def get_properties(device_sn, node, *properties)
        properties.inject({}) do |info, property|
          cmd = "adb -s #{device_sn} shell getprop #{node}.#{property}"
          property_value = `#{cmd}`.strip
          info[property] = property_value.empty? ? 'N/A' : property_value
          info
        end
      end
    end
    
    private_class_method :synthesize_command, :get_properties
  end
  end


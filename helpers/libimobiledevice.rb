module MobileDevicePool
  class LibImobileDevice
    @@product_type_name_map = File.open(File.join(File.dirname(__FILE__), 'ios_product_type_name_map'), 'r') do |f|
      list = {}
      while line = f.gets
        if line.match(/^#.*/).nil?
          map = line.strip.split('=')
          list[map.first] = map.last
        end
      end
      list
    end
    
    class << self
      def list_devices
        `idevice_id --list`.split("\n")
      end
      
      def list_devices_with_details
        devices = list_devices.inject([]) do |devices, udid|
          device = {}
          device['udid'] = udid
          device['model'] = get_model_name(udid)
          device['os'] = get_os_version(udid)
          device['battery'] = get_battery_level(udid)
          device['namedevice'] = get_device_name(udid)
          str = get_app_version(udid)
          puts str
          matchdata = get_string_between(str, "de.intelligentapps.mytaxibeta, \"", "\", \"mytaxi beta")
          device['appversion'] = matchdata
          matchdata = get_string_between(str, "de.intelligentapps.mytaxi, \"", "\", \"mytaxi alpha")
          device['appversionAlpha'] = matchdata
          matchdata = get_string_between(str, "de.intelligentapps.mytaxiDriver, \"", "\", \"mytaxi Driver")
          device['driverAppversion'] = matchdata
          matchdata = get_string_between(str, "de.intelligentapps.mytaxiDriverAlpha, \"", "\", \"mytaxi Driver α")
          device['driverAppversionAlpha'] = matchdata
          devices.push(device)
        end
      end

      def get_string_between(my_string, start_at, end_at)
        my_string = " #{my_string}"
        ini = my_string.index(start_at)
        return my_string if ini == 0
        ini += start_at.length
        length = my_string.index(end_at, ini).to_i - ini
        my_string[ini,length]
      end
      
      def get_os_version(udid)
        get_info('ideviceinfo', udid, 'ProductVersion')
      end
      
      def get_product_name(udid)
        @@product_type_name_map[get_info('ideviceinfo', udid, 'ProductType')]
      end

      def get_model_name(udid)
        get_info('ideviceinfo', udid, 'ProductType')
      end

      def get_device_name(udid)
        get_info('ideviceinfo', udid, 'DeviceName')
      end

      def get_app_version(udid)
        `ideviceinstaller -u #{udid} -l`.strip
      end
      
      def get_battery_level(udid)
        get_info('ideviceinfo', udid, 'BatteryCurrentCapacity', 'com.apple.mobile.battery')
      end
      
      def install_app(file)
        jobs = list_devices.inject([]) do |result, udid|
          job = Proc.new do
            `ideviceinstaller -u #{udid} -i #{file}`
          end
          result.push(job)
        end
        concurrent_runner = ConcurrentRunner.set
        concurrent_runner.set_producer_thread(jobs)
        concurrent_runner.set_consumer_thread
        concurrent_runner.run
      end
      
      def get_info(cmd, udid, key, domain = nil)
        if domain && key
          `#{cmd} -u #{udid} -q #{domain} -k #{key}`.strip
        elsif key
          `#{cmd} -u #{udid} -k #{key}`.strip
        else
          `#{cmd} -u #{udid}`.strip
        end
      end
    end
    
    private_class_method :get_info
  end
end
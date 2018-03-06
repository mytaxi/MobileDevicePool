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
          device['model'] = get_product_name(udid)
          device['os'] = get_os_version(udid)
          device['battery'] = get_battery_level(udid)
          str = get_app_version(udid)
          matchdata = str.match(/mytaxi beta(.*?)\n/)
          device['appversion'] = matchdata
          str = get_app_version(udid)
          matchdata = str.match(/mytaxi alpha(.*?)\n/)
          device['appversionAlpha'] = matchdata
          str = get_app_version(udid)
          matchdata = str.match(/mytaxi Driver(.*?)\n/)
          device['driverAppversion'] = matchdata
          str = get_app_version(udid)
          matchdata = str.match(/mytaxi Driver α(.*?)\n/)
          device['driverAppversionAlpha'] = matchdata

          devices.push(device)
        end
      end
      
      def get_os_version(udid)
        get_info('ideviceinfo', udid, 'ProductVersion')
      end
      
      def get_product_name(udid)
        @@product_type_name_map[get_info('ideviceinfo', udid, 'ProductType')]
      end

      def get_app_version(udid)
        `ideviceinstaller -l`.strip
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
        if domain
          `#{cmd} -u #{udid} -q #{domain} -k #{key}`.strip
        else
          `#{cmd} -u #{udid} -k #{key}`.strip
        end
      end
    end
    
    private_class_method :get_info
  end
end
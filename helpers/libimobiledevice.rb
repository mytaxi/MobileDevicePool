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
          matchdata = str[/de.intelligentapps.mytaxibeta - mytaxi beta (.*?)\n/, 1]
          #matchdata = str
          device['appversion'] = matchdata
          matchdata = str[/de.intelligentapps.mytaxi - mytaxi alpha (.*?)\n/, 1]
          device['appversionAlpha'] = matchdata
          matchdata = str[/de.intelligentapps.mytaxiDriver - mytaxi Driver (.*?)\n/, 1]
          device['driverAppversion'] = matchdata
          matchdata = str[/de.intelligentapps.mytaxiDriverAlpha - mytaxi Driver α (.*?)\n/, 1]
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
            puts 'install on:'+udid
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
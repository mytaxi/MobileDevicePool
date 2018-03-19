require_relative 'import'
require 'fileutils'

module MobileDevicePool
  class App < Sinatra::Base
    register Sinatra::Namespace

    $pwd = ENV['PWD']
    
    # Common APIs
    # ==================================================
    namespace '/api/devices' do
      get '/?' do
        content_type :json
        android_devices = Adb.list_devices_with_details
        ios_devices = LibImobileDevice.list_devices_with_details
        devices = {}
        devices['android'] = android_devices
        devices['ios'] = ios_devices
        json devices
      end
    end
    
    # iOS APIs
    # ==================================================
    namespace '/api/devices/ios' do
      get '/?' do
        content_type :json
        devices = LibImobileDevice.list_devices_with_details
        json devices
      end

      post '/alpha/:filename' do
        userdir = File.join("files", params[:alpha])
        FileUtils.mkdir_p(userdir)
        filename = File.join(userdir, params[:filename])
        datafile = params[:data]
        File.open(filename, 'wb') do |file|
          file.write(datafile[:tempfile].read)
        end
        file = File.join($pwd, filename)
        if file
          result = LibImobileDevice.install_app(file)
          result.first ? [201, result[1].to_json] : [500, result[1].to_json]
        else
          return 500
        end
      end

      post '/beta/:filename' do
        userdir = File.join("files", params[:beta])
        FileUtils.mkdir_p(userdir)
        filename = File.join(userdir, params[:filename])
        datafile = params[:data]
        File.open(filename, 'wb') do |file|
          file.write(datafile[:tempfile].read)
        end
        file = File.join($pwd, filename)
        if file
          result = LibImobileDevice.install_app(file)
          result.first ? [201, result[1].to_json] : [500, result[1].to_json]
        else
          return 500
        end
      end
    end

    # Android APIs
    # ==================================================
    #
    namespace '/api/devices/android' do
      get '/?' do
        content_type :json
        devices = Adb.list_devices_with_details
        json devices
      end

      # Packages
      # ==================================================
      get '/:device_sn/packages/?' do |device_sn|
        content_type :json
        json Adb.list_installed_packages(device_sn)
      end

      get '/:device_sn/packages/:package_name/?' do
        content_type :json
        json Adb.get_app_info(params[:package_name], params[:device_sn])
      end
      
      delete '/:device_sn/packages/:package_name/?' do
        Adb.uninstall_app(params[:package_name], params[:device_sn]) ? 204 : 404
      end
      
      delete '/:device_sn/packages/:package_name/data/?' do
        Adb.clear_app(params[:package_name], params[:device_sn]) ? 204 : 404
      end
      
      # Activities
      # ==================================================
      get '/:device_sn/activities/focused/?' do |device_sn|
        content_type :json
        json [Adb.get_current_activity(device_sn)]
      end

      post '/:alpha/:filename' do
        userdir = File.join("files", params[:alpha])
        FileUtils.mkdir_p(userdir)
        filename = File.join(userdir, params[:filename])
        datafile = params[:data]
        File.open(filename, 'wb') do |file|
          file.write(datafile[:tempfile].read)
        end
        file = File.join($pwd, filename)
        if file
          result = Adb.install_app_multiple_devices(file)
          result.first ? [201, result[1].to_json] : [500, result[1].to_json]
        else
          return 500
        end
      end

      post '/:beta/:filename' do
        userdir = File.join("files", params[:beta])
        FileUtils.mkdir_p(userdir)
        filename = File.join(userdir, params[:filename])
        datafile = params[:data]
        File.open(filename, 'wb') do |file|
          file.write(datafile[:tempfile].read)
        end
        file = File.join($pwd, filename)
        if file
          result = Adb.install_app_multiple_devices(file)
          result.first ? [201, result[1].to_json] : [500, result[1].to_json]
        else
          return 500
        end
      end


      post '/:device_sn/screenshots/?' do |device_sn|
        content_type :json
        result = take_a_screenshot(settings.screenshot_dir, device_sn)
        settings.screenshot_files = get_screenshots_files(settings.screenshot_dir)
        result.first ? [201, result[1].to_json] : [500, result[1].to_json]
      end
      
      put '/:device_sn/?' do |device_sn|
        request.body.rewind
        json = request.body.read.to_s
        if json && json.length >= 2
          req_data = JSON.parse(json)
          language = req_data['language']
          country = req_data['country']
          if language && country
            Thread.start{ Adb.change_language(language, country, device_sn) }
            return 202
          else
            return 400
          end
        else
          return 400
        end
      end
      
      post '/:device_sn/deeplinks/?' do |device_sn|
        request.body.rewind
        json = request.body.read.to_s
        if json && json.length >= 2
          req_data = JSON.parse(json)
          package_name = req_data['packageName']
          deep_link = req_data['deepLink']
          if package_name && deep_link
            result = Adb.open_app_via_deep_link(package_name, deep_link, device_sn)
            result.first ? [201, result[1].to_json] : [500, result[1].to_json]
          else
            return 500
          end
        else
          return 500
        end
      end
    end
    
    # Frontend
    # ==================================================
    namespace '/devices' do
      get '/?' do
        @use_pnotify = true
        @use_jquery_ui = true
        haml :devices
      end
    end
  end
end


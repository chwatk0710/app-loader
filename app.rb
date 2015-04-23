require 'gibberish'
require 'haml'

VM_APP_PATH = "/var/www/entercom"
RAILS_ENV = "production"
SHARED_KEY = "asdfasdf"

class AppLoader < Sinatra::Base
  get '/setup' do
    haml :index
  end

  post '/setup/upload' do
    tmp_license_contents = params[:license_file][:tempfile].read

    cipher = Gibberish::AES.new(SHARED_KEY)

    begin
      license = JSON.parse cipher.decrypt tmp_license_contents
    rescue
      return redirect to("/setup/error")
    end

    unless version = license['version']
      return redirect to("/setup/error")
    end

    if params[:package_file]
      tmp_package_file = params[:package_file][:tempfile]
      package = cipher.decrypt tmp_package_file.read

      tmp_package_file.rewind
      tmp_package_file.write package

      puts "#{tmp_package_file.path} extract to #{VM_APP_PATH}"
      puts `tar xvf #{tmp_package_file.path} -C #{VM_APP_PATH}`
      `mkdir #{VM_APP_PATH}/tmp`

      db_cmd = "db:create db:migrate"
      puts `cd #{VM_APP_PATH}; RAILS_ENV=#{RAILS_ENV} bundle exec rake #{db_cmd}`
    end

    File.open(File.join(VM_APP_PATH, 'tmp/license.enc'), 'w') do |f|
      f.write tmp_license_contents
    end

    `touch #{VM_APP_PATH}/tmp/restart.txt`

    redirect "/"
  end

  get "/setup/error" do
    haml :error
  end
end

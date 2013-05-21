require 'rubygems'
require 'sinatra'


set :public_folder, File.dirname(__FILE__) + '/website'

get '/' do
	          send_file File.join(settings.public_folder, 'index.html')
end

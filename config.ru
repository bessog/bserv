require 'sinatra'
require 'sinatra/base'
require 'geoip'
require 'mongo'
require 'haml'
require './bserv'

map '/' do
  run BServApp
end

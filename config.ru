require 'yaml'
require 'cf-runtime'
require 'sinatra'
require 'sinatra/base'
require 'mongo'
require 'geoip'
require 'erb'
require './bserv'

map '/' do
  run BServApp
end

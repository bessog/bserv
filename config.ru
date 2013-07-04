require 'yaml'
require 'cf-runtime'
require 'sinatra'
require 'sinatra/base'
require 'mongo'
require 'haml'
require './bserv'

map '/' do
  run BServApp
end

class BServApp < Sinatra::Base
  set :show_exceptions, false
  #set :views, File.join(File.dirname(__FILE__), 'views/bserv')
  set :views, 'views/bserv'
  set :public_folder, 'public/bserv'
  
  if ENV['VCAP_SERVICES'] then
    #puts "Running on CloudFoundry"
    db = CFRuntime::MongoClient.create_from_svc 'mongolab-bserv'
  else
    puts "Running local"
    db = Mongo::MongoClient.new("localhost", 27017).db('local-bserv')
  end

  not_found { erb :'404'}

  time = Time.new
  timeutc = time.utc()
  time_id = BSON::ObjectId.from_time(timeutc)

  get '/gb/:where/?:test?/?:ip?' do
    coll = db.collection("GeoipBannerCollection")
    coll.ensure_index({"loc" => "2dsphere" })
    if params[:ip].is_a? String then client_ip = params[:ip]
    else client_ip = request.ip end

    client_location = GeoIP.new("GeoLiteCity.dat").city(client_ip)

    query = {
      "_id" => {
        "$lt" => time_id
      }, 
     "loc" => {
        "$near" => {
          "$geometry" => {
            "type" => "Point",
            "coordinates" => [ 
              client_location[:longitude],
              client_location[:latitude]
            ]
          }
        },
        "$maxDistance" => 200000
      }
    }

    row = coll.find(query).to_a
    show = row[rand(row.length)]

    puts show
    #erb :index
  end

  get '/bn/:where/?:short?/?:test?' do
    coll = db.collection("GenericBannerCollection")
    if(params[:short].nil?) then short = 'default' else short = params[:short] end

    query = {
      "_id" => {
        "$lt" => time_id
      },
      "short" => params[:short]
    }

    show = coll.find_one(query)
    puts show

    #erb :index
  end  

end

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

  coll = db.collection('Banners')

  not_found { erb :'404'}

  time = Time.new
  timeutc = time.utc()
  time_id = BSON::ObjectId.from_time(timeutc)

  get '/gb/:where/?:test?/?:ip?' do
    #coll.ensure_index({"loc" => "2dsphere" })
    if params[:ip].is_a? String then client_ip = params[:ip]
    else client_ip = request.ip end
    ipA = client_ip.split('.')
    ipInt = 16777216 * ipA[0].to_i + 65536 * ipA[1].to_i + 256 * ipA[2].to_i + ipA[3].to_i

    coll = db.collection("GeoLiteCity")
    query = { "$and" => [
      { "startIpNum" => { "$lte" =>  ipInt }},
      { "endIpNum" => { "$gte" =>  ipInt }}
    ]}
    rb=coll.find_one(query).to_a

    query = { "_id" => rb[3][1] }
    rl=coll.find_one(query).to_a

    coll = db.collection("Banners")
    query = {
      "_id" => {
        "$lt" => time_id
      }, 
     "loc" => {
        "$near" => {
          "$geometry" => {
            "type" => "Point",
            "coordinates" => [ 
              rl[6][1],
              rl[5][1]
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
    coll = db.collection("Banners")
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

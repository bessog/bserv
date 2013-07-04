class BServApp < Sinatra::Base

  set :show_exceptions, true
  set :views, 'views'
  set :public_folder, 'public'
  
  dbyml = YAML.load_file('database.yml')

  if ENV['VCAP_SERVICES'] then
    dbconf = dbyml["cloudfoundry"]
  else
    puts "Running local"
    dbconf = dbyml["local"] 
  end

  db = Mongo::MongoClient.new(dbconf["host"], dbconf["port"]).db(dbconf["database"])
  if !dbconf["password"].nil? then auth = db.authenticate(dbconf["username"], dbconf["password"]) end

  not_found { haml :error404 }

  time = Time.new
  timeutc = time.utc()
  time_id = BSON::ObjectId.from_time(timeutc)

  get '/gb/:where/?:test?/?:ip?' do

begin_t = Time.now

    if params[:ip].is_a? String then client_ip = params[:ip]
    else client_ip = request.ip end

    ipA = client_ip.split('.')
    ipInt = 16777216 * ipA[0].to_i + 65536 * ipA[1].to_i + 256 * ipA[2].to_i + ipA[3].to_i

    coll = db.collection("GeoLiteCity-Blocks")

    query = { "$query" => {"startIpNum" => { "$lte" =>  ipInt }}, "$orderby" => { "startIpNum" => -1 } } 
#puts coll.find(query).explain()
#begin_t = Time.now
    rb=coll.find_one(query).to_a
#end_t = Time.now
#puts "time #{(end_t - begin_t)*1000} milliseconds"

    @show = {}

    if rb.any? then
      coll = db.collection("GeoLiteCity-Location")
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
#puts coll.find(query).explain()
#begin_t = Time.now
      row = coll.find(query).to_a
#end_t = Time.now
#puts "time #{(end_t - begin_t)*1000} milliseconds"
      if row.length > 0 then @show = row[rand(row.length)]
      else @show["message"] = "none found" end
    else @show["message"] = "none found" end

end_t = Time.now
@show["Banner generated in "] = " #{(end_t - begin_t)*1000} milliseconds"

    haml :banner
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

    @show = coll.find_one(query)

    haml :banner
  end  

end

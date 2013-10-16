class BServApp < Sinatra::Base

  set :show_exceptions, true
  set :views, 'views'
  set :public_folder, 'public'
  
  dbyml = YAML.load_file('database.yml')

  if ENV['VCAP_SERVICES'] then
    @debug = false
    dbconf = dbyml["cloudfoundry"]
  else
    @debug = false
    puts "Running local"
    dbconf = dbyml["local"]
  end

  db = Mongo::MongoClient.new(dbconf["host"], dbconf["port"]).db(dbconf["database"])
  if !dbconf["password"].nil? then auth = db.authenticate(dbconf["username"], dbconf["password"]) end

  not_found { erb :error404 }

  get '/gb/:where/?:test?/?:ip?' do

    if @debug then begin_t = Time.now end

    if params[:ip].is_a? String then client_ip = params[:ip]
    else client_ip = request.ip end

    rl = GeoIP.new('GeoLiteCity.dat').city(client_ip)

    @show = {}

    if @debug then @show["client ip "] = client_ip end

    coll = db.collection("Styles")
    query = {}
    css = coll.find_one(query)
    @show["css"] = css["css"]

    if @debug then @show["client location "] = rl end

    coll = db.collection("Banners")

    query = {
      "end_date" => { "$gt" => Time.now.utc },
      "active" => "YES",
      "loc" => {
        "$near" => {
          "$geometry" => {
            "type" => "Point",
            "coordinates" => [ 
              rl.longitude,
              rl.latitude
            ]
          }
        },
        "$maxDistance" => 200000
      }
    }

    if @debug then @show["query"] = query end
    @show["banner"] = {}

    if @debug then @show["explain"] = coll.find(query).explain() end
    #if @debug then begin_qt = Time.now end
    row = coll.find(query).to_a
    #if @debug then end_qt = Time.now end
    #if @debug then @show["query time"] = "time #{(end_qt - begin_qt)*1000} milliseconds" end

    if row.length > 0 then @show['banner'] = row[rand(row.length)]
    else @show["banner"]["body"] = "none found" end

    if @debug then 
      end_t = Time.now
      @show["Banner generated in "] = " #{(end_t - begin_t)*1000} milliseconds"
    end

    erb :banner
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

    erb :banner
  end  

end

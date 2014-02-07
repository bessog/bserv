class BServApp < Sinatra::Base

  set :show_exceptions, true
  set :views, 'views'
  set :public_folder, 'public'
  
  dbyml = YAML.load_file('database.yml')
  defaults = YAML.load_file('defaults.yml')

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

  get '/gb/:site/?:test?/?:ip?' do

    defaultbanner = true
    @show = {}
    @show["banner"] = {}
    @debug = false
    @test = false

    if params[:test] == "2" then @debug = true
    elsif params[:test] == "1" then @test = true end

    if @debug then begin_t = Time.now end

    if params[:ip] then client_ip = params[:ip]
    else client_ip = request.ip end

    if @debug then @show["client ip "] = client_ip end

    rl = GeoIP.new('GeoLiteCity.dat').city(client_ip)
    if @debug then @show["client location "] = rl.to_a end

    if params[:site] then site = params[:site]
    else site = defaults['site'] end
    coll = db.collection("Styles")
    query = {}
    css = coll.find_one({"site" => site})
    @show["css"] = "<style>" + css["css"] + "</style>"

    coll = db.collection("Banners")

    if defined? rl.longitude then 
      defaultbanner = false

      query = {
        "end_date" => { "$gt" => Time.now.utc },
        "active" => true,
        "type" => defaults['type'],
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

      if @debug then
        @show["query"] = query
        @show["explain"] = coll.find(query).explain()
        begin_qt = Time.now 
      end
      row = coll.find(query).to_a
      if @debug then 
        end_qt = Time.now
        @show["query time"] = "time #{(end_qt - begin_qt)*1000} milliseconds"
      end

      if row.length < 1 then defaultbanner = true end
    end

    if defaultbanner then
      query = {
        "end_date" => { "$gt" => Time.now.utc },
        "active" => true,
        "type" => defaults['type'],
        "fields.city" => defaults['city']
      }
      if @debug then begin_2qt = Time.now end
      row = coll.find(query).to_a
      if @debug then
        end_2qt = Time.now
        @show["2nd query time"] = "time #{(end_2qt - begin_2qt)*1000} milliseconds"
      end
    end

    @show["banner"] = row[rand(row.length)]
    fields = @show["banner"]["fields"]

    if @debug then 
      end_t = Time.now
      @show["fields: "] = fields['title']
      @show["Banner generated in "] = " #{(end_t - begin_t)*1000} milliseconds"
    end

    js_date = DateTime.parse(fields['start_date'].to_s).strftime('%-d %b %Y')

    gaPiAd = "<script>
(function(i,s,o,g,r,a,m){i[\'GoogleAnalyticsObject\']=r;i[r]=i[r]||function(){
(i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
})(window,document,\'script\',\'//www.google-analytics.com/analytics.js\',\'gaPiAd\');
gaPiAd(\'create\', \'" + defaults['gaaccount'] + "\', \'none\');
gaPiAd(\'send\', \'event\', \'Impression\', \'" + fields['title'].to_s + " - " + js_date + " - " + fields['city'].to_s + "\', location.href);
var gaPiAdClick_" + fields['class_id'].to_s + " = function() { gaPiAd(\'send\', \'event\', \'Click\', \'" + fields['title'].to_s + " - " + js_date + " - " + fields['city'].to_s + "\', location.href) };
</script>"

    if !@debug && !@test then headers['Content-Type'] = 'application/javascript' end

    if @debug then
      erb :banner
    elsif @test then
      "<script>document.write(unescape('" + CGI.escape(gaPiAd + @show['css'] + @show['banner']['body']).gsub("+", "%20") + "'));</script>"
    else
      "document.write(unescape('" + CGI.escape(gaPiAd + @show['css'] + @show['banner']['body']).gsub("+", "%20") + "'));"
    end

  end

=begin
  get '/bn/:site/?:short?/?:test?' do
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
=end

end

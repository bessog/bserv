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

    if params[:site] then paramsite = params[:site]
    else paramsite = defaults['site'] end
    coll = db.collection("Sites")

    query = {
        "end_date" => { "$gt" => Time.now.utc },
        "active" => true,
        "type" => defaults['type']
    }

    site = coll.find_one({"site" => paramsite})

    if site["filter"] then
      YAML.load(site["filter"]).each do |k,v|
        query[k] = v
      end
    end
    
    @show["css"] = site["css"]

    coll = db.collection("Banners")

    if defined? rl.longitude then 
      defaultbanner = false

      query["loc"] = {
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

      if row.length < 1 then 
        defaultbanner = true
        query.delete("loc")
      end
    end

    if defaultbanner then
      query["fields.city"] = defaults["city"]

      if @debug then begin_2qt = Time.now end
      row = coll.find(query).to_a
      if @debug then
        end_2qt = Time.now
        @show["2nd query time"] = "time #{(end_2qt - begin_2qt)*1000} milliseconds"
      end
    end
    
    query = {
        "end_date" => { "$gt" => Time.now.utc },
        "active" => true,
        "type" => "Generic"
    }
    genrow = coll.find(query).to_a
    
    resBanner = [genrow, row].flatten
    
    rando = rand(resBanner.length)
    
    if @debug then 
      @show["resBanner: "] = resBanner
      @show["resBanner.length: "] = resBanner.length
      @show["rando: "] = rando
    end
    
    @show["banner"] = resBanner[rando]
    
    if @show["banner"] then
      if @show["banner"]["fields"] then
        fields = @show["banner"]["fields"]
      end
    else
      fbquery = {}
      defaults["gbfallback"].each do |k,v|
        fbquery[k] = v.to_s
      end
      row = coll.find(fbquery).to_a
      @show["banner"] = row[0]
      if @show["banner"]["fields"] then
        fields = @show["banner"]["fields"]
      end
    end

    if @debug then 
      end_t = Time.now
      if fields then
        @show["fields: "] = fields['title']
      end
      @show["whole row: "] = @show["banner"]
      @show["Banner generated in "] = " #{(end_t - begin_t)*1000} milliseconds"
    end

    gaPiAd = "
(function(i,s,o,g,r,a,m){i[\'GoogleAnalyticsObject\']=r;i[r]=i[r]||function(){
(i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
})(window,document,\'script\',\'//www.google-analytics.com/analytics.js\',\'gaPiAd\');
gaPiAd(\'create\', \'" + defaults['gaaccount'] + "\', \'none\');
gaPiAd(\'send\', \'event\', \'Impression\', \'" + @show["banner"]["adname"] + "\', location.href);
var gaPiAdClick_" + @show["banner"]["_id"].to_s + " = function() { gaPiAd(\'send\', \'event\', \'Click\', \'" + @show["banner"]["adname"] + "\', location.href) };
"

    if !@debug && !@test then headers['Content-Type'] = 'application/javascript' end

    output = "gapiAds = document.getElementsByClassName('PivotalAdBannerDiv');
for(i=0; i<gapiAds.length; i++) {
  s = document.createElement('script');
  s.type = 'text/javascript';
  s.text = '" + gaPiAd.gsub("\n"," ").gsub("'","\\\\'") +"';
  gapiAds[i].parentNode.insertBefore(s,gapiAds[i]);
  c = document.createElement('style');
  c.innerHTML = '" + @show['css'].gsub("\n"," ").gsub("'","\\\\'") + "';
  document.head.appendChild(c);
  gapiAds[i].innerHTML='" + @show['banner']['body'].gsub("\n"," ").gsub("'","\\\\'") + "';
}"

    if @debug then
      erb :banner
    elsif @test then
"<div class='PivotalAdBannerDiv'></div>
<script>" + output + "</script>"
    else
      output
    end

=begin
# NOTE
# async banner loader
<div class='PivotalAdBannerDiv'></div>
<script>
(function() {
    var s = document.createElement('script');
    s.type = 'text/javascript';
    s.async = true;
    s.src = 'http://example.com/gb/site.com';
    var x = document.getElementsByTagName('script')[0];
    x.parentNode.insertBefore(s, x);
})();
</script>
=end

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

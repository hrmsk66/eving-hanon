sub vcl_recv {

  if (req.request != "GET" && req.request != "HEAD" && req.request != "FASTLYPURGE") {
    error 405;
  }

#FASTLY recv

  # No wonky paths.
  if (req.url.path ~ "/(/|\.(/|\./))") {
    error 400;
  }


  # filter out unexpected query string params
  if (req.url != req.url.path) {
    # filter params allowed for each case
    if (req.url.ext ~ "m3u8|mpd" && req.url.path !~ ",master\.(m3u8|mpd)$") {
      set req.url = querystring.regfilter_except(req.url, "^(iframe)$");

    } elsif (req.url.ext ~ "ts|fmp4") {
      set req.url = querystring.regfilter_except(req.url, "^(iframe)$");

    } elsif (req.url.path ~ ",master\.(m3u8|mpd)$") {
      set req.url = querystring.regfilter_except(req.url, "^()$");

    # In all other cases, any query parameters must be stripped.
    } else {
      set req.url = req.url.path;
    }
  }

  return(lookup);
}

sub vcl_miss {

#FASTLY miss


  # Set backend to shield if request is from the edge, otherwise set backend to OTFP
  set req.backend = get_backend_otfp_vpop_haf_https();
  if (!is_backend_otfp()) {
    # Insert any custom logic here
    # Go to shield.
    return (fetch);
  }

  # set bereq.http.X-Fastly-Origin = "https://eving-hanon.s3.us-west-1.amazonaws.com";
  set bereq.http.X-Fastly-Origin = "https://us-west.object.fastlystorage.app";
  set bereq.http.X-Fastly-Whitelist = "Origin Origin-Credentials Demuxed Extension Hls-No-Captions";
  # set bereq.http.X-Fastly-Origin-Credentials = table.lookup(otfp, "credentials");
  set bereq.http.X-Fastly-Origin-Credentials = table.lookup(otfp, "hanon");
  if (bereq.url.ext == "mpd") {
    set bereq.http.X-Fastly-Demuxed = "true";
  }
  set bereq.http.X-Fastly-Extension = ".m4a";
  set bereq.http.X-Fastly-Hls-No-Captions  = "true";

  # Trim query parameters if present.
  set bereq.url = "/hanon" req.url.path;

  # Parse and handle ABR manifest requests.

  if (bereq.url ~ "^(.+\/)([^\/]+)(\/)([^\/]+),master\.(m3u8|mpd)$") {
    declare local var.basedir STRING;
    declare local var.basename STRING;
    declare local var.delimiter STRING;
    declare local var.renditions STRING;
    declare local var.extension STRING;
    declare local var.multi-affix STRING;

    set var.basedir = re.group.1;    # /a/b/c/
    set var.basename = re.group.2;   # base name / prefix
    set var.delimiter = re.group.3;  # "/","-","_" etc
    set var.renditions = re.group.4; # lo,mid,hi
    set var.extension = re.group.5;  # mpd, m3u8

    # renditions is at least 1, up to 10, file names, separated by commas.
    if (var.renditions !~ "^[^,]+(,[^,]+){0,9}$") {
      error 400 "Invalid request";
    }

    set bereq.url = var.basedir var.basename "/basic_multi." var.extension;

    # tailor affix
    set var.multi-affix = " ";

    # construct a space-separated list of renditions
    set bereq.http.X-Fastly-Basic-Multi = var.multi-affix std.replaceall(var.renditions, ",", var.multi-affix);

    # see vcl_hash
    set bereq.http.X-Fastly-Base-Url = "https://" req.http.host var.basedir var.basename;
    set bereq.http.X-Fastly-Whitelist = bereq.http.X-Fastly-Whitelist " Basic-Multi Base-Url";

    if (req.url.ext == "m3u8") {
      set bereq.http.X-Fastly-Iframe-Param = "iframe";
      set bereq.http.X-Fastly-Whitelist = bereq.http.X-Fastly-Whitelist " Iframe-Param";
    }

    # Client identity shall match each individual rendition (see below)
    set client.identity = var.basedir + var.basename;

  } else {

    if (subfield(req.url.qs, "iframe", "&")) {
      set bereq.http.X-Fastly-Iframe-Param = "iframe";
      set bereq.http.X-Fastly-Whitelist = bereq.http.X-Fastly-Whitelist " Iframe-Param";
    }
    

    # /a/b/c/lo,mid,hi/master.m3u8 must have the same ID as /a/b/c/lo.m3u8, etc.
    set client.identity = regsub(bereq.url, "/[^/]+$", "");
  }

  return(fetch);
}

sub vcl_fetch {

  ################################################################################
  ### Added by Fastly staff. Reduces number of copies of an object stored per POP.
  ### For customers with large working sets, increases cache hit ratio.
  ### Do not remove!
  set beresp.reduced_redundancy = true;
  ################################################################################

  # Enable Streaming Miss only for video or audio objects.
  # Below conditions checks for video or audio file extensions commonly used in
  # HTTP Streaming formats.
  if (req.url.ext ~ "aac|dash|m4s|mp4|ts") {
    set beresp.do_stream = true;
  }

  if (beresp.status >= 500 && beresp.status < 600 || beresp.status == 400 || beresp.status == 404) {
    set beresp.cacheable = true;
    set beresp.ttl = 5m;
    set beresp.stale_if_error = 60m;
  } else {
    set beresp.ttl = 86400s;
    set beresp.stale_if_error = 8w;
  }

#FASTLY fetch

  return(deliver);
}

sub vcl_deliver {

  if (client.requests == 1) {
    # increase init cwnd for only client requests
    set client.socket.cwnd = 45;
    # set congestion algorithm for client requests
    set client.socket.congestion_algorithm = "bbr";
  }
  if (fastly.ff.visits_this_service == 0) {
    # attach CORS headers for only edge responses
    set resp.http.Access-Control-Allow-Origin = "*";
    set resp.http.Access-Control-Allow-Methods = "GET";
  }
#FASTLY deliver

  return(deliver);
}

sub vcl_hash {

  # The embedded "base url" in each ABR manifest is fully qualified, including
  # the original request scheme.
  if (req.url.path ~ ",master\.(m3u8|mpd)$") {
    set req.hash += if(req.is_ssl, "1", "0");
  }

  set req.hash += req.url;
  set req.hash += req.http.Host;

#FASTLY hash

  return (hash);
}


# generated by OTFP Builder v0.98.0 - keep the comment for tracking

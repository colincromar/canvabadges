class DomainFudger
  def initialize(app)
    @app = app
  end
  
  def call(env)
    scheme = env['rack.url_scheme']
    host = env['HTTP_HOST']
    path = env['PATH_INFO'] || ""
    domain = host
    env['badges.path_prefix'] = ""
    if path.match(/^\/_/)
      nothing, domain_piece, new_path = path.split(/\//, 3)
      domain += "/" + domain_piece
      env['PATH_INFO'] = "/" + new_path
      env['badges.path_prefix'] = "/" + domain_piece
      env['REQUEST_URI'] = scheme + "://" + host + "/" + new_path
      if env['QUERY_STRING'] && env['QUERY_STRING'].length > 0
        env['REQUEST_URI'] += "?" + env['QUERY_STRING']
      end
      env['REQUEST_PATH'] = "/" + new_path
    end
    env['badges.domain'] = domain
    @app.call(env)
  end
end
Description
===========

Stasis plugin for asset stamping with git revisions, environment branching,
and uri helpers.

Installation
============

    % gem install homeostasis

In your controller:

    require 'rubygems'
    require 'homeostasis/asset'   # for asset stamping
    require 'homeostasis/env'     # for environment handler
    require 'homeostasis/path'    # for path helpers

Each component is optional.

Usage
=====

By default, assets matching `/\.(jpg|png|gif|css|js)$/i` will be stamped.
So if your root directory is like this:

    background.jpg
    index.html.haml
    script.js
    styles.css

You'll end up with something like this:

    background.sha1.jpg
    index.html
    script.sha1.js
    styles.sha1.css

In your views, use the `asset_path` helper:

    %img{:src => asset_path('background.jpg')}

For CSS files, I use the extension `.erb` like `styles.css.erb`:

    background: url(<%= asset_path('background.jpg') %>);

You can set the regex for asset matching in your controller:

    Homeostasis::Asset.matcher = /myregex$/i

You can even concat your assets into a single file:

    # in controller.rb
    Homeostasis::Asset.concat 'all.js', %w(jquery.js mine.js)
    Homeostasis::Asset.concat 'all.css', %w(reset.css mine.css)

    # in views
    %link{:href => asset_path('all.css')}
    %script{:src => asset_path('all.js')}

The environment handler just adds a variable:

    Homeostasis::ENV

It's set to whatever `HOMEOSTASIS_ENV` or `'development'` by default.  You
can use this to branch in your view:

    = Homeostasis::ENV.development? ? 'local.js' : 'production.js'

The path helper uses the environment handler.  It just adds the view helper
`path` which returns differently depending on the environment:

    path('/blog')  # development => '/blog.html' 
    path('/blog')  # production  => '/blog/' 

This goes along well with an `htaccess` file that drops the `.html` extensions
from requests and adds trailing slashes.

License
=======

Copyright 2012 Hugh Bien - http://hughbien.com.
Released under BSD License, see LICENSE.md for more info.
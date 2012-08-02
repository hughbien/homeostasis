Description
===========

Stasis plugin for asset stamping, blogs, front-matter yaml, and trailing slash.

Installation
============

    % gem install homeostasis

In your controller:

    require 'rubygems'
    require 'homeostasis/asset'   # for asset stamping
    require 'homeostasis/blog'    # for blog support
    require 'homeostasis/front'   # for yaml front-matter
    require 'homeostasis/trail'   # for trailing slashes

Each component is optional.

Asset Stamping
==============

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

Generated files in the `public` directory will go through a global search and
replace.

You can set the regex for asset matching in your controller:

    Homeostasis::Asset.matcher = /myregex$/i

You can even concat your assets into a single file:

    Homeostasis::Asset.concat 'all.js', %w(jquery.js mine.js)
    Homeostasis::Asset.concat 'all.css', %w(reset.css mine.css)

Blog
====

In your controller:

    Homeostasis::Blog.create('blog') # directory of posts

Post files should be in the format `yyyy-mm-dd-permalink.html.{md,haml}` and
have YAML front-matter:

    <!--
      :title: Title Goes Here
    -->

You'll have to create your own `blog/index.html`.  Use the `blog_posts` helper
to construct it:

    - blog_posts.each do |post|
      %a{:href => post[:path]}= post[:title]

Stick this in your controller for an RSS feed:

    Homeostasis::Blog.rss('rss.xml')

Front-Matter YAML
=================

This adds YAML front-matter support:

    #!
      :title: Lorem Ipsum
      :desc:  Quick fox over lazy dog.
    %div
      Page continues as normal here
    %h1= front[:title]
    %p= front[:desc]

Note the 2-space indentation is required.  This works for HTML, Markdown, and
ERB comments as well:

    <!--
      :title: Lorem Ipsum
    -->
    Continue as normal

You can configure which files to check in `controller.rb`.  Here's the default:

    Homeostasis::Front.matchers = {
      'erb'  => /<%#/,
      'haml' => /-#/,
      'html' => /<!--/,
      'md'   => /<!--/
    }

Just start the file with YAML inside a comment with 2-space indentation.  The
data will be available from the `front` method in your views and controller.
There's also a `front_site` helper which contains the data for all pages for
cross-page access.

Note that `:path` is automatically assigned if left blank.  Its value will be
the production path to the page.  If the trailing slash plugin is included,
the `html` extension will be lost.

Trailing Slash
==============

This turns every page into a directory with an `index.html` file.  So instead
of:

    index.html
    blog.html
    about.html

You'll get:

    index.html
    blog/index.html
    about/index.html

This works well with an `htaccess` file that automatically appends trailing
slashes to URLs.

License
=======

Copyright 2012 Hugh Bien - http://hughbien.com.
Released under BSD License, see LICENSE.md for more info.

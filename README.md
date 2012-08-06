Description
===========

Stasis plugin for asset stamping, blogs, front-matter yaml, sitemaps, and
trailing slashes.

Installation
============

    % gem install homeostasis

In your controller:

    require 'rubygems'
    require 'homeostasis'

This requires the current directory to be under `git` version control.

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
replace.  By default, it'll only do this on `html`, `css`, and `js` files.
You can configure this:

    Homeostasis::Asset.replace_matcher = /.(html|css|js)$/i

You can set the regex for asset matching in your controller:

    Homeostasis::Asset.matcher = /myregex$/i

You can also configure concatenation of multiple assets into a single file:

    Homeostasis::Asset.concat 'all.js', %w(jquery.js mine.js)
    Homeostasis::Asset.concat 'all.css', %w(reset.css mine.css)

Blog
====

In your controller:

    Homeostasis::Blog.directory('blog') # directory of posts

Post files should be in the format `yyyy-mm-dd-permalink.html.{md,haml}`.  Use
YAML front-matter for any metadata you want.  `:date` and `:path` will be
added automatically for you.

    <!--
      :title: Title Goes Here
    -->

You'll have to create your own `blog/index.html`.  Use the `blog_posts` helper
to construct it:

    - blog_posts.each do |post|
      %span.date post[:date].strftime("%m/%d/%Y")
      %a{:href => post[:path]}= post[:title]

Front-Matter YAML
=================

In your views:

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
the public path to the page.

Sitemap
=======

A sitemap will automatically be generated in `public/sitemap.xml`.  You'll need
to set the root URL for this to happen:

    Homeostasis::Sitemap.url 'http://example.com'

`loc` and `lastmod` will be generated for each page.  Use front-yaml to set the
`changefreq` or `priority`:

    <!--
      :changefreq: monthly
      :priority: 0.9
    -->

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

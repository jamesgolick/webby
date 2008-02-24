# $Id$

module Webby::Resources

# A rudimentary "database" for holding resource objects and finding them.
# The database is held in a Ruby hash keyed by the directories in the
# content folder.
#
class DB

  # call-seq:
  #    DB.new
  #
  # Create a new resources database object. This is used to store resources
  # and to find them by their attributes.
  #
  def initialize
    @db = Hash.new {|h,k| h[k] = []}
  end

  # call-seq:
  #    add( resource )    => resource
  #
  # Add the given _resource_ to the database. It will not be added a second
  # time if it already exists in the database.
  #
  def add( page )
    ary = @db[page.dir]

    # make sure we don't duplicate pages
    ary.delete page if ary.include? page
    ary << page

    page
  end
  alias :<< :add

  # call-seq:
  #    clear    => self
  #
  # Removes all resources from the database.
  #
  def clear
    @db.clear
    self
  end

  # call-seq:
  #    each {|resource| block}
  #
  # Iterate over each resource in the database and pass it to the given
  # block.
  #
  def each( &b )
    keys = @db.keys.sort
    keys.each do |k|
      @db[k].sort.each(&b)
    end
    self
  end

  # call-seq:
  #    find( opts = {} )                       => resource or nil
  #    find( opts = {} ) {|resource| block}    => resource or nil
  #
  # Find a specific resource or collection of resources in the pages database.
  # Resources can be found using any combination of attributes by passing them
  # in as options to the +find+ method. This will used simple equality
  # comparison to find the resource or resources.
  # 
  # If the :include option is given as :all then all resources that match
  # the finder criteria will be returned in an array. If none are found, an
  # empty array will be returned. If the :include option is given as an
  # integer then the first n resources found will be returned. Otherwise, or
  # if the :include option is not given, the first resource found will be
  # returned
  # 
  # For more complex finders, a block should be supplied. The usage follows
  # that of of the Enumerable#find or Enumerable#find_all methods, depending
  # on the limit. The method will return the first resource or all
  # resources, respectively, for which the block returns true.
  # 
  # Options:
  #    :limit        => :all, integer or nil
  #    :in_directory => directory
  #    :recursive    => true or false
  #    :sort_by      => attribute
  #    :reverse      => true or false
  #
  # Examples:
  #
  #    # find the "index" resource in the "foo/bar" directory
  #    @pages.find( :filename => 'index', :in_directory => 'foo/bar' )
  #
  #    # find all resources under the "foo/bar" directory recursively
  #    @pages.find( :limit => :all, :in_directory => 'foo/bar', :recursive => true )
  #
  #    # find the resource named "widgets" whose color is "blue"
  #    @pages.find( :name => 'widgets', :color => 'blue' )
  #
  #    # find all resources created in the past week
  #    @pages.find( :limit => :all ) do |resource|
  #      resource.created_at > Time.now - (7 * 24 * 3600)
  #    end
  #
  def find( *args, &block )
    opts = Hash === args.last ? args.pop : {}

    limit = opts.delete(:limit)
    sort_by = opts.delete(:sort_by)
    reverse = opts.delete(:reverse)

    # figure out which directories to search through and whether to recurse
    # into directories or not
    search = if (dir = opts.delete(:in_directory))
      strategy = if opts.delete(:recursive)
        lambda { |key| key =~ /^#{Regexp.escape(dir)}(?:\/|$)/ }
      else
        lambda { |key| key == dir }
      end
      matching_keys = @db.keys.select(&strategy)
      raise RuntimeError, "unknown directory '#{dir}'" if matching_keys.empty?
      matching_keys.map { |key| @db[key] }.flatten
    else
      self
    end

    # construct a search block if one was not supplied by the user
    block ||= lambda do |page|
      found = true
      opts.each do |key, value|
        found &&= page.__send__(key.to_sym) == value
        break if not found
      end
      found
    end
    
    # search through the directories for the desired pages
    ary = []
    search.each do |page|
      ary << page if block.call(page)
    end

    # sort the search results if the user gave an attribute to sort by
    if sort_by
      m = sort_by.to_sym
      ary.delete_if {|p| p.__send__(m).nil?}
      reverse ? 
          ary.sort! {|a,b| b.__send__(m) <=> a.__send__(m)} :
          ary.sort! {|a,b| a.__send__(m) <=> b.__send__(m)} 
    end

    # limit the search results
    case limit
    when :all, 'all'
      ary
    when Integer
      ary.slice(0,limit)
    else
      ary.first
    end
  end

  # call-seq:
  #    siblings( page, opts = {} )    => array
  #
  # Returns an array of resources that are siblings of the given _page_
  # resource. A sibling is any resource that is in the same directory as the
  # _page_.
  #
  # Options include:
  #
  #    :sorty_by => 'attribute'
  #    :reverse  => true
  #
  def siblings( page, opts = {} )
    ary = @db[page.dir].dup
    ary.delete page
    return ary unless opts.has_key? :sort_by

    m = opts[:sort_by]
    ary.sort! {|a,b| a.__send__(m) <=> b.__send__(m)}
    ary.reverse! if opts[:reverse]
    ary
  end

  # call-seq:
  #    children( page, opts = {} )    => array
  #
  # Returns an array of resources that are children of the given _page_
  # resource. A child is any resource that exists in a subdirectory of the
  # page's directory.
  #
  # Options include:
  #
  #    :sorty_by => 'attribute'
  #    :reverse  => true
  #
  def children( page, opts = {} )
    rgxp = Regexp.new "\\A#{page.dir}/[^/]+"

    keys = @db.keys.find_all {|k| rgxp =~ k}
    ary  = keys.map {|k| @db[k]}
    ary.flatten!

    return ary unless opts.has_key? :sort_by

    m = opts[:sort_by]
    ary.sort! {|a,b| a.__send__(m) <=> b.__send__(m)}
    ary.reverse! if opts[:reverse]
    ary
  end

end  # class DB
end  # module Webby

# EOF
module Xapit
  # This is the object used in the block of the xapit method in Xapit::Membership. It keeps track of the
  # index settings for a given class. It also provides some indexing functionality.
  class IndexBlueprint
    attr_reader :text_attributes
    attr_reader :field_attributes
    attr_reader :facets
    
    # Indexes all classes known to have an index blueprint defined.
    def self.index_all
      load_models
      @@instances.each do |member_class, blueprint|
        yield(member_class) if block_given?
        blueprint.index_all
      end
    end
    
    def initialize(member_class, *args)
      @member_class = member_class
      @args = args
      @text_attributes = {}
      @field_attributes = []
      @facets = []
      @@instances ||= {}
      @@instances[member_class] = self # TODO make this thread safe
    end
    
    # Adds a text attribute. Each word in the text will be indexed as a separate term allowing full text searching.
    # Text terms are what is searched by the primary string in a search query.
    #
    #   Article.search("kite")
    #
    def text(*attributes, &block)
      attributes.each do |attribute|
        @text_attributes[attribute] = block
      end
    end
    
    # Adds a field attribute. Field terms are not split by word so it is not designed for full text search.
    # Instead you can filter through a field using the :conditions hash in a search query.
    #
    #   Article.search("", :conditions => { :priority => 5 })
    #
    def field(*attributes)
      @field_attributes += attributes
    end
    
    # Adds a facet attribute. See Xapit::FacetBlueprint and Xapit::Facet for details.
    def facet(*args, &block)
      @facets << FacetBlueprint.new(@member_class, @facets.size, *args, &block)
    end
    
    def document_for(member)
      document = Xapian::Document.new
      document.data = "#{member.class}-#{member.id}"
      terms(member).each do |term|
        document.add_term(term)
      end
      values(member).each do |index, value|
        document.add_value(index, value)
      end
      save_facet_options_for(member)
      document
    end
    
    def terms(member)
      base_terms(member) + field_terms(member) + text_terms(member) + facet_terms(member)
    end
    
    def base_terms(member)
      ["C#{member.class}", "Q#{member.class}-#{member.id}"]
    end
    
    def text_terms(member)
      text_attributes.map do |name, proc|
        content = member.send(name).to_s
        if proc
          proc.call(content).map(&:downcase)
        else
          content.scan(/[a-z0-9]+/i).map(&:downcase)
        end
      end.flatten
    end
    
    def field_terms(member)
      field_attributes.map do |name|
        "X#{name}-#{member.send(name).to_s.downcase}"
      end
    end
    
    def facet_terms(member)
      facets.map do |facet|
        facet.identifiers_for(member).map { |id| "F#{id}" }
      end.flatten
    end
    
    def values(member)
      index = 0
      facets.inject(Hash.new) do |hash, facet|
        hash[index] = facet.identifiers_for(member).join("-")
        index += 1
        hash
      end
    end
    
    # Indexes all records of this blueprint class. It does this using the ".find_each" method on the member class.
    def index_all
      @member_class.find_each(*@args) do |member|
        Config.writable_database.add_document(document_for(member))
      end
    end
    
    def save_facet_options_for(member)
      facets.each do |facet|
        facet.save_facet_options_for(member)
      end
    end
    
    private
    
    # Make sure all models are loaded - without reloading any that
    # ActiveRecord::Base is already aware of (otherwise we start to hit some
    # messy dependencies issues).
    # 
    # Taken from thinking-sphinx
    def self.load_models
      if defined? Rails
        base = "#{Rails.root}/app/models/"
        Dir["#{base}**/*.rb"].each do |file|
          model_name = file.gsub(/^#{base}([\w_\/\\]+)\.rb/, '\1')
      
          next if model_name.nil?
          next if ::ActiveRecord::Base.send(:subclasses).detect { |model|
            model.name == model_name
          }
      
          begin
            model_name.camelize.constantize
          rescue LoadError
            model_name.gsub!(/.*[\/\\]/, '').nil? ? next : retry
          rescue NameError
            next
          end
        end
      end
    end
  end
end

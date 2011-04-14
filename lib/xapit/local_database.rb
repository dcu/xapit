module Xapit
  class LocalDatabase
    def initialize(path, template_path)
      @path = path
      @template_path = template_path
    end

    def readable_database
      writable_database
    end

    def writable_database
      @writable_database ||= generate_database
    end

    def add_document(document)
      writable_database.add_document(build_xapian_document(document))
    end

    def delete_document(id)
      writable_database.delete_document(id)
    end

    def replace_document(id, document)
      writable_database.replace_document(id, build_xapian_document(document))
    end

    def get_spelling_suggestion(term)
      readable_database.get_spelling_suggestion(term)
    end

    def add_spelling(term)
      writable_database.add_spelling(term)
    end

    def doccount
      readable_database.doccount
    end

    private

    def generate_database
      FileUtils.mkdir_p(File.dirname(@path)) unless File.exist?(File.dirname(@path))
      if @template_path && !File.exist?(@path)
        FileUtils.cp_r(@template_path, @path)
      end
      Xapian::WritableDatabase.new(@path, Xapian::DB_CREATE_OR_OPEN)
    end

    def build_xapian_document(document)
      xapian_doc = Xapian::Document.new
      xapian_doc.data = "#{document.id}#{document.data}"
      document.terms.each_with_index do |term, index|
        xapian_doc.add_term(term, document.term_weights[index] || 1)
      end
      document.values.each_with_index do |value, index|
        xapian_doc.add_value(document.value_indexes[index], value)
      end
      document.spellings.each do |spelling|
        writable_database.add_spelling(spelling)
      end
      xapian_doc
    end
  end
end

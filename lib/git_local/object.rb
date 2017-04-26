module GitLocal
  class Object
    attr_reader :path

    class NotFound < StandardError
    end

    def initialize(path)
      @path = path
    end

    def name
      path.rindex("/") ? path[path.rindex("/") + 1..-1] : path
    end

    def read(max_lines = nil)
      return contents if max_lines.nil?

      File.foreach(path).first(max_lines).join
    rescue StandardError
      raise NotFound
    end

    def sha
      Digest::SHA1.hexdigest("blob " + contents.length.to_s + "\0" + contents)
    end

    def size
      File.size(path).to_f / 2**20
    end

    private

    def contents
      @contents ||= File.read(path)
    end
  end
end

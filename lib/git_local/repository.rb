module GitLocal
  class Repository
    class NotFound < StandardError
    end

    class InvalidArgument < StandardError
    end

    def initialize(org:, repo:, branch:, local_directory:)
      check_for_special_characters(org, repo, branch, local_directory)
      @org = org
      @repo = repo
      @branch = branch
      @local_directory = local_directory
    end

    def get
      Dir.exist?(path) && new_commit_on_remote? ? pull : clone_and_checkout
    end

    def file_object(file_path)
      GitLocal::Object.new(File.join(path, file_path))
    end

    def file_objects(file_path = nil)
      repo_path = file_path.nil? ? path : File.join(path, file_path)
      searchable_repo_path = repo_path.end_with?("/") ? repo_path : "#{repo_path}/"

      Dir.glob("#{searchable_repo_path}*").each_with_object([]) do |filename, git_files|
        next if %w(. ..).include?(filename) || File.extname(filename) == ".zip" || File.directory?(filename)

        git_files << GitLocal::Object.new(filename)
      end
    end

    def all_file_objects(file_path = nil, include_dirs = false)
      repo_path = file_path.nil? ? path : File.join(path, file_path)
      searchable_repo_path = repo_path.end_with?("/") ? repo_path : "#{repo_path}/"
      Dir.glob("#{searchable_repo_path}**/*").each_with_object([]) do |filename, git_files|
        if !File.directory?(filename) || include_dirs
          git_files << GitLocal::Object.new(filename)
        end
      end
    end

    def local_path(file_path)
      file_path.gsub("#{path}/", "")
    end

    def new_commit_on_remote?
      popened_io = IO.popen("(cd #{path} && git rev-parse HEAD)")
      head = popened_io.read.chomp.split("\n").last
      Process.wait(popened_io.pid)

      popened_io = IO.popen("(cd #{path} && git remote update && git rev-parse origin/#{branch})")
      remote = popened_io.read.chomp
      Process.wait(popened_io.pid)
      raise NotFound unless $?.to_i == 0

      remote != head
    end

    def path
      @path ||= "#{local_directory}/#{org_repo_branch}"
    end

    def check_for_special_characters(*args)
      regexp = Regexp.new(/([A-Za-z0-9\-\_\/#]+)/)
      args.each do |arg|
        raise InvalidArgument if arg.gsub(regexp, '').length > 0
      end
    end

    private

    attr_reader :org, :repo, :branch, :local_directory

    def clone_and_checkout
      FileUtils.makedirs(repo_path) unless Dir.exist?(repo_path)

      popened_io = IO.popen("(cd #{repo_path} && git clone git@github.com:#{org_repo}.git --branch #{branch} --single-branch #{branch} && cd #{path})")
      Process.wait(popened_io.pid)

      raise NotFound unless $?.to_i == 0
    end

    def org_repo
      @org_repo ||= "#{org}/#{repo}"
    end

    def org_repo_branch
      @org_repo_branch ||= "#{org}/#{repo}/#{branch}"
    end

    def pull
      Process.wait(IO.popen("(cd #{path} && git pull)").pid)
    end

    def repo_path
      @repo_path ||= "#{local_directory}/#{org_repo}"
    end
  end
end

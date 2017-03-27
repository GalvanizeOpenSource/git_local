require 'fileutils'

module GitLocal
  module TestHelpers
    def create_git_repository(org:, repo:, branch:, local_directory:, file_paths: [], size: nil)
      repo_path = GitLocal::Repository.new(org: org, repo: repo, branch: branch, local_directory: local_directory).path

      FileUtils.mkdir_p(repo_path)

      file_paths.each do |file_path|
        create_file("#{repo_path}/#{file_path}", size)
      end
    end

    def write_local_git_file(org:, repo:, branch:, file_path:, file_contents:, local_directory:)
      repo_path = GitLocal::Repository.new(org: org, repo: repo, branch: branch, local_directory: local_directory).path

      file = File.open("#{repo_path}/#{file_path}", "w")
      file.puts(file_contents)
      file.close
    end

    def remove_all_repositories(path)
      repositories = File.join(path, "**", "*")
      FileUtils.rm_rf Dir.glob(repositories)
    end

    def create_file(path, size = nil)
      dir = File.dirname(path)

      FileUtils.mkdir_p(dir) unless File.directory?(dir)

      File.new(path, "w")

      return if size.nil?

      File.open(path, "wb") do |f|
        size.to_i.times { f.write(SecureRandom.random_bytes(2**20)) }
      end
    end
  end
end

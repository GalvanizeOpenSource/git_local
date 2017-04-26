require "spec_helper"

describe GitLocal::Object do
  let(:file_path) { "file1.md" }
  let(:local_directory) { File.join(Dir.getwd, "tmp") }
  let(:repo_args) { { org: "cool_org", repo: "awesome_repo", branch: "brunch-1", local_directory: local_directory } }

  after { remove_all_repositories(local_directory) }

  describe "attributes" do
    let(:path) { "/Path/To/App/AppName/repositories/RepoOrg/RepoName/RepoBranch/FilePath" }

    it "can be valid" do
      expect(described_class.new(path).path).to eq("/Path/To/App/AppName/repositories/RepoOrg/RepoName/RepoBranch/FilePath")
    end

    it "raises an error if no path is given" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end

  describe "#read" do
    context "when the local file does not exist" do
      let(:git_file_object) { described_class.new("#{local_directory}/cool_org/awesome_repo/brunch-1/file1.md") }

      it "raises FileNotFound" do
        expect { git_file_object.read }.to raise_error(described_class::NotFound)
      end
    end

    context "when the local file exists" do
      before { create_git_repository(repo_args.merge(file_paths: [file_path])) }

      it "returns the file contents" do
        write_local_git_file(repo_args.merge(file_path: file_path, file_contents: "lessons on why Jordan rocks"))

        gfo = described_class.new("#{local_directory}/cool_org/awesome_repo/brunch-1/file1.md")

        expect(gfo.read).to eq "lessons on why Jordan rocks\n"
      end

      context "when a max number of lines is specified" do
        it "returns the file contents limited by line number when lines are passed" do
          write_local_git_file(repo_args.merge(file_path: file_path, file_contents: "lessons on why Jordan rocks\ntickle bunnies\ntopple monger\nfarkle and fart\n"))

          gfo = described_class.new("#{local_directory}/cool_org/awesome_repo/brunch-1/file1.md")

          expect(gfo.read(2)).to eq "lessons on why Jordan rocks\ntickle bunnies\n"
        end

        it "reads the all lines if the file contains less lines than the max lines to read passed in" do
          write_local_git_file(repo_args.merge(file_path: file_path, file_contents: "line 1\nline 2\nline 3\nline 4\n"))

          gfo = described_class.new("#{local_directory}/cool_org/awesome_repo/brunch-1/file1.md")

          expect(gfo.read(10)).to eq "line 1\nline 2\nline 3\nline 4\n"
        end
      end
    end
  end

  describe "#name" do
    it "returns the file name" do
      gfo = described_class.new("#{local_directory}/cool_org/awesome_repo/brunch-1/file1.md")
      expect(gfo.name).to eq "file1.md"
    end
  end

  describe "#sha" do
    before do
      create_git_repository(repo_args.merge(file_paths: [file_path]))
      write_local_git_file(repo_args.merge(file_path: file_path, file_contents: ("lessons on why Peter rocks\ntickle bunnies\ntopple monger\nfarkle and fun\n")))
    end

    it "returns SHA1 in the same format as GitHub" do
      gfo = described_class.new("#{local_directory}/cool_org/awesome_repo/brunch-1/file1.md")
      expected_sha = Digest::SHA1.hexdigest("blob 71\0lessons on why Peter rocks\ntickle bunnies\ntopple monger\nfarkle and fun\n")
      regular_sha = Digest::SHA1.hexdigest("lessons on why Peter rocks\ntickle bunnies\ntopple monger\nfarkle and fun\n")

      expect(gfo.sha).to_not eq regular_sha
      expect(gfo.sha).to eq expected_sha
    end
  end

  describe "#size" do
    let(:path) { "file1.md" }

    before { create_git_repository(repo_args.merge(file_paths: [path], size: 5)) }

    it "returns the file size in MB" do
      gfo = described_class.new("#{local_directory}/cool_org/awesome_repo/brunch-1/file1.md")
      expect(gfo.size).to eq(5.0)
    end
  end
end

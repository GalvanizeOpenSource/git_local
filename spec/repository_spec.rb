require "spec_helper"

describe GitLocal::Repository do
  let(:local_directory) { File.join(Dir.getwd, "tmp") }
  let(:valid_args) { { org: "cool_org", repo: "awesome_repo", branch: "brunch-1", local_directory: local_directory } }

  after { remove_all_repositories(local_directory) }

  describe "#get" do
    let(:action) { described_class.new(valid_args).get }

    context "repo exists" do
      before { create_git_repository(valid_args) }

      it "checks out and pulls a repo if there is a new commit on remote" do
        expect(IO).to receive(:popen).with("(cd #{local_directory}/cool_org/awesome_repo/#{valid_args[:branch]} && git rev-parse HEAD)").and_return(double(read: "something", pid: 1))
        dbl2 = double(read: "something-else", pid: 2)
        expect(IO).to receive(:popen).with("(cd #{local_directory}/cool_org/awesome_repo/#{valid_args[:branch]} && git remote update && git rev-parse origin/#{valid_args[:branch]}) 2>&1").and_return(dbl2)
        allow(dbl2).to receive(:map)
        expect(IO).to receive(:popen).with("(cd #{local_directory}/cool_org/awesome_repo/#{valid_args[:branch]} && git fetch && git reset origin/#{valid_args[:branch]} --hard)").and_return(double(read: "content", pid: 3))
        expect(Process).to receive(:wait).with(1)
        expect(Process).to receive(:wait).with(2)
        expect(Process).to receive(:wait).with(3)

        action
      end

      it "raises a repo not found error if the check for updates on the remote fails" do
        RSpec::Mocks.configuration.allow_message_expectations_on_nil = true

        expect(IO).to receive(:popen).with("(cd #{local_directory}/cool_org/awesome_repo/brunch-1 && git rev-parse HEAD)").and_return(double(read: "something", pid: 1))
        dbl = double(read: "something-else", pid: 2)
        expect(IO).to receive(:popen).with("(cd #{local_directory}/cool_org/awesome_repo/brunch-1 && git remote update && git rev-parse origin/brunch-1) 2>&1").and_return(dbl)
        allow(dbl).to receive(:map)
        expect(Process).to receive(:wait).with(1)
        expect(Process).to receive(:wait).with(2)
        expect($?).to receive(:to_i).and_return(1)

        expect { action }.to raise_error(described_class::NotFound)

        RSpec::Mocks.configuration.allow_message_expectations_on_nil = false
      end
    end

    context "repo does not exist locally" do
      it "clones a repo that doesn't already exist in file system" do
        expect(Dir.exist?("#{local_directory}/cool_org/awesome_repo/")).to be false
        dbl = double(pid: 1)
        expect(IO).to receive(:popen).with(
          "(cd #{local_directory}/cool_org/awesome_repo && git clone git@github.com:cool_org/awesome_repo.git --branch brunch-1 --single-branch brunch-1 && cd #{local_directory}/cool_org/awesome_repo/brunch-1) 2>&1"
        ).and_return(dbl)
        allow(dbl).to receive(:map)
        expect(Process).to receive(:wait).with(1)

        action
      end

      context "given bad args" do
        let(:bad_args) { { org: "Some", repo: "Bad", branch: "Repo", local_directory: local_directory } }

        it "raises a repo not found error if the clone fails" do
          RSpec::Mocks.configuration.allow_message_expectations_on_nil = true

          expect(Dir.exist?("#{local_directory}/Some/Bad/")).to be false
          dbl = double(pid: 1)
          expect(IO).to receive(:popen).with(
            "(cd #{local_directory}/Some/Bad && git clone git@github.com:Some/Bad.git --branch Repo --single-branch Repo && cd #{local_directory}/Some/Bad/Repo) 2>&1"
          ).and_return(dbl)
          expect(dbl).to receive(:map).and_return(["test", "message"])
          expect(Process).to receive(:wait).with(1)
          expect($?).to receive(:to_i).and_return(1)

          expect { described_class.new(bad_args).get }.to raise_error(described_class::NotFound).with_message("test message")

          RSpec::Mocks.configuration.allow_message_expectations_on_nil = nil
        end
      end
    end
  end

  describe "#file_object" do
    let(:path) { "folder/file.md" }
    before { create_git_repository(valid_args.merge(file_paths: [path])) }

    it "returns a GitLocal::File for a repo and file path" do
      found_file = described_class.new(valid_args).file_object(path)

      expect(found_file).to be_instance_of(GitLocal::Object)
      expect(found_file).to have_attributes(path: "#{local_directory}/cool_org/awesome_repo/brunch-1/folder/file.md")
    end
  end

  describe "#file_objects" do
    context "repo contains two files, one in a subfolder" do
      let(:file_path) { "file1.md" }
      let(:file_path_2) { "folder/file2.md" }

      before { create_git_repository(valid_args.merge(file_paths: [file_path, file_path_2])) }

      context "when no path is passed" do
        it "returns a git object for all files in the root repo folder" do
          files = described_class.new(valid_args).file_objects

          expect(files.length).to eq(1)
          expect(files[0].class).to eq GitLocal::Object
          expect(files[0].path).to include(file_path)
        end
      end

      context "path is an existing folder" do
        it "returns a git object for all files in a repo folder" do
          files = described_class.new(valid_args).file_objects("folder/")

          expect(files.length).to eq(1)
          expect(files[0].class).to eq GitLocal::Object
          expect(files[0].path).to include(file_path_2)
        end
      end
    end

    context "folder contains a zip file" do
      before { create_git_repository(valid_args.merge(file_paths: ["folder/subfolder/file.zip"])) }

      it "does not return the zip file object" do
        files = described_class.new(valid_args).file_objects("folder/subfolder")
        expect(files.length).to eq(0)
      end
    end
  end

  describe "#all_file_objects" do
    let(:file_path) { "file1.md" }
    before { create_git_repository(valid_args.merge(file_paths: [file_path, file_path_2])) }

    context "path is nil" do
      let(:file_path_2) { "file2.pdf" }

      it "returns a git object for all files in a repo" do
        files = described_class.new(valid_args).all_file_objects

        expect(files.length).to eq(2)
        expect(files[0].class).to eq GitLocal::Object
        expect(files[0].path).to include("cool_org/awesome_repo/brunch-1/file1.md")
        expect(files[1].class).to eq GitLocal::Object
        expect(files[1].path).to include("cool_org/awesome_repo/brunch-1/file2.pdf")
      end
    end

    context "path is not nil" do
      let(:file_path_2) { "folder/file2.pdf" }

      it "returns a git object for all files in a repo" do
        files = described_class.new(valid_args).all_file_objects

        expect(files.length).to eq(2)
        expect(files[0].path).to include("/cool_org/awesome_repo/brunch-1/file1.md")
        expect(files[1].path).to include("/cool_org/awesome_repo/brunch-1/folder/file2.pdf")
      end
    end

    context "include_dirs is true" do
      let(:file_path_2) { "folder/file2.pdf" }

      it "returns all git objects including objects for directories" do
        files = described_class.new(valid_args).all_file_objects(nil, true)

        expect(files.length).to eq(3)
        expect(files[0].path).to include("/cool_org/awesome_repo/brunch-1/file1.md")
        expect(files[1].path).to include("/cool_org/awesome_repo/brunch-1/folder")
        expect(files[2].path).to include("/cool_org/awesome_repo/brunch-1/folder/file2.pdf")
      end
    end
  end

  describe "#local_path" do
    context "file path contains full repo path" do
      let(:file_path) { "#{local_directory}/cool_org/awesome_repo/brunch-1/file1.md" }

      it { expect(described_class.new(valid_args).local_path(file_path)).to eq("file1.md") }
    end

    context "file path does not contain full repo path" do
      it { expect(described_class.new(valid_args).local_path("file1.md")).to eq("file1.md") }
    end
  end

  describe "#path" do
    it "returns the file system path for a repo" do
      expect(described_class.new(valid_args).path).to eq "#{local_directory}/cool_org/awesome_repo/brunch-1"
    end
  end

  describe "#new_commit_on_remote?" do
    it "returns true if there is a new commit" do
      expect(IO).to receive(:popen).with("(cd #{local_directory}/cool_org/awesome_repo/brunch-1 && git rev-parse HEAD)").and_return(double(read: "something", pid: 1))
      dbl = double(read: "something-else", pid: 2)
      expect(IO).to receive(:popen).with("(cd #{local_directory}/cool_org/awesome_repo/brunch-1 && git remote update && git rev-parse origin/brunch-1) 2>&1").and_return(dbl)
      allow(dbl).to receive(:map)
      expect(Process).to receive(:wait).with(1)
      expect(Process).to receive(:wait).with(2)

      expect(described_class.new(valid_args).new_commit_on_remote?).to eq(true)
    end

    it "returns false if there is not a new commit" do
      expect(IO).to receive(:popen).with("(cd #{local_directory}/cool_org/awesome_repo/brunch-1 && git rev-parse HEAD)").and_return(double(read: "something", pid: 1))
      dbl = double(read: "something", pid: 2)
      expect(IO).to receive(:popen).with("(cd #{local_directory}/cool_org/awesome_repo/brunch-1 && git remote update && git rev-parse origin/brunch-1) 2>&1").and_return(dbl)
      allow(dbl).to receive(:map)
      expect(Process).to receive(:wait).with(1)
      expect(Process).to receive(:wait).with(2)

      expect(described_class.new(valid_args).new_commit_on_remote?).to eq(false)
    end
  end

  describe "#check_for_special_characters" do
    it "raises an error if the passed arguments contain unexpected characters" do
      bad_args = { org: "Some!", repo: "$Bad", branch: "Repo^%", local_directory: local_directory }
      expect { described_class.new(bad_args) }.to raise_error(described_class::InvalidArgument)
    end

    it "allows letter, numbers, dashes, underscores, periods and hashes" do
      args = { org: "So.me/totally", repo: "fine_to#use", branch: "arg-123", local_directory: local_directory }
      expect { described_class.new(args) }.to_not raise_error
    end
  end

  describe "host override" do
    let(:host) { "git.sum.enterprise.org" }
    let(:action) { described_class.new(valid_args.merge(host: host)).get }

    it "clones and checks out repositories from non-github hosts" do
      dbl = double(pid: 1)
      expect(IO).to receive(:popen) do |command|
        expect(command).to include(host)
      end.and_return(dbl)
      allow(dbl).to receive(:map)
      expect(Process).to receive(:wait).with(1)
      action
    end
  end

  describe "protocol override" do
    let(:action) { described_class.new(valid_args.merge(protocol: protocol)).get }

    context "valid protocol" do
      let(:protocol) { "HTTPS" }

      it "clones and checks out repositories using the protocol provided" do
        dbl = double(pid: 1)
        expect(IO).to receive(:popen) do |command|
          expect(command).to include(protocol.downcase)
        end.and_return(dbl)
        allow(dbl).to receive(:map)
        expect(Process).to receive(:wait).with(1)
        action
      end
    end

    context "invalid protocol" do
      let(:protocol) { "FTP" }

      it "raises an error if the protocol is neither SSH nor HTTPS" do
        expect { action }.to raise_error(GitLocal::Repository::InvalidProtocol)
      end
    end
  end
end

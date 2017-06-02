require "resque"
require "linters/runner"
require "linters/rubocop/options"

describe Linters::Runner do
  describe "#call" do
    context "when linter encounters an error" do
      it "enqueues a job with an error" do
        config = <<~EOS
          Style/StringLiterals:
          Enabled: true
        EOS
        attributes = {
          "commit_sha" => "foobar",
          "config" => config,
          "content" => "puts 'hello world'",
          "filename" => "foo.rb",
          "linter_name" => "rubocop",
          "patch" => "",
          "pull_request_number" => "123",
        }
        allow(Resque).to receive(:enqueue)

        described_class.call(
          linter_options: Linters::Rubocop::Options.new,
          attributes: attributes,
        )

        expect(Resque).to have_received(:enqueue).with(
          CompletedFileReviewJob,
          commit_sha: attributes["commit_sha"],
          filename: attributes["filename"],
          linter_name: attributes["linter_name"],
          patch: attributes["patch"],
          pull_request_number: attributes["pull_request_number"],
          violations: [],
          error: a_string_including("Warning: unrecognized cop Enabled found"),
        )
      end

      context "when error output is a recursive stack-trace" do
        it "reports error using its unique lines" do
          attributes = {
            "commit_sha" => "foobar",
            "config" => "",
            "content" => "puts 'hello world'",
            "filename" => "foo.rb",
            "linter_name" => "rubocop",
            "patch" => "",
            "pull_request_number" => "123",
          }
          output = <<~EOS
            something went wrong:
              foo.rb
              foo.rb
              foo.rb
              Stack buffer overflow
          EOS
          command_result = instance_double(
            "CommandResult",
            output: output,
            error?: true,
          )
          allow(Resque).to receive(:enqueue)
          allow(Linters::CommandResult).to receive(:new).
            and_return(command_result)

          described_class.call(
            linter_options: Linters::Rubocop::Options.new,
            attributes: attributes,
          )

          expect(Resque).to have_received(:enqueue).with(
            CompletedFileReviewJob,
            commit_sha: attributes["commit_sha"],
            filename: attributes["filename"],
            linter_name: attributes["linter_name"],
            patch: attributes["patch"],
            pull_request_number: attributes["pull_request_number"],
            violations: [],
            error: <<~EOS
              something went wrong:
                foo.rb
                Stack buffer overflow
            EOS
          )
        end
      end
    end
  end
end

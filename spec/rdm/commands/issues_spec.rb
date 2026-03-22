# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Rdm::Commands::Issues do
  let(:tmpdir) { Dir.mktmpdir("rdm_test") }
  let(:config_path) { File.join(tmpdir, "config.yml") }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("RDM_CONFIG", anything).and_return(config_path)
    allow(ENV).to receive(:fetch).with("RDM_URL", nil).and_return(nil)
    allow(ENV).to receive(:fetch).with("RDM_API_KEY", nil).and_return(nil)
    allow(ENV).to receive(:fetch).with("RDM_PROFILE", nil).and_return(nil)
    allow(ENV).to receive(:fetch).with("RDM_DEBUG", anything).and_return(nil)
    allow(ENV).to receive(:fetch).with("RDM_TIMEOUT", nil).and_return(nil)
    allow(ENV).to receive(:fetch).with("RDM_FORMAT", nil).and_return(nil)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("RDM_DEBUG").and_return(nil)

    # Set up config
    config = Rdm::Config.new(config_path)
    config.save_profile(url: "https://redmine.example.com", api_key: "test_key")
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#list" do
    it "lists issues with default parameters" do
      stub_request(:get, "https://redmine.example.com/issues.json")
        .with(query: hash_including("status_id" => "open", "limit" => "25", "offset" => "0"))
        .to_return(status: 200, body: {
          "issues" => [
            { "id" => 1, "subject" => "Bug report",
              "tracker" => { "id" => 1, "name" => "Bug" },
              "status" => { "id" => 1, "name" => "New" },
              "priority" => { "id" => 2, "name" => "Normal" },
              "assigned_to" => { "id" => 3, "name" => "John" },
              "updated_on" => "2026-03-22" }
          ],
          "total_count" => 1
        }.to_json, headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], { format: "json", status: "open", limit: 25, offset: 0 })
      expect { cmd.list }.to output(/Bug report/).to_stdout
    end

    it "filters by project" do
      stub_request(:get, "https://redmine.example.com/issues.json")
        .with(query: hash_including("project_id" => "myproject"))
        .to_return(status: 200, body: { "issues" => [], "total_count" => 0 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], { format: "json", project_id: "myproject", status: "open", limit: 25, offset: 0 })
      expect { cmd.list }.to output.to_stdout
    end
  end

  describe "#show" do
    it "shows issue details" do
      stub_request(:get, "https://redmine.example.com/issues/123.json")
        .to_return(status: 200, body: {
          "issue" => {
            "id" => 123, "subject" => "Fix login timeout",
            "project" => { "id" => 1, "name" => "Main" },
            "tracker" => { "id" => 1, "name" => "Bug" },
            "status" => { "id" => 2, "name" => "In Progress" },
            "priority" => { "id" => 3, "name" => "High" },
            "author" => { "id" => 1, "name" => "Jane" },
            "assigned_to" => { "id" => 2, "name" => "John" },
            "description" => "Session timeout issue"
          }
        }.to_json, headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], { format: "json" })
      expect { cmd.show("123") }.to output(/Fix login timeout/).to_stdout
    end

    it "handles not found" do
      stub_request(:get, "https://redmine.example.com/issues/99999.json")
        .to_return(status: 404, body: "", headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], { format: "json" })
      expect { cmd.show("99999") }.to raise_error(Rdm::NotFoundError)
    end
  end

  describe "#create" do
    it "creates an issue with required fields" do
      stub_request(:post, "https://redmine.example.com/issues.json")
        .with(body: hash_including("issue" => hash_including("subject" => "New issue")))
        .to_return(status: 201, body: {
          "issue" => { "id" => 456, "subject" => "New issue",
                       "project" => { "id" => 1, "name" => "Main" },
                       "tracker" => { "id" => 1, "name" => "Bug" },
                       "status" => { "id" => 1, "name" => "New" } }
        }.to_json, headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], {
        format: "json", project_id: "main", tracker_id: 1, subject: "New issue"
      })
      expect { cmd.create }.to output(/456/).to_stdout
    end

    it "handles validation errors" do
      stub_request(:post, "https://redmine.example.com/issues.json")
        .to_return(status: 422, body: {
          "errors" => ["Subject cannot be blank"]
        }.to_json, headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], {
        format: "json", project_id: "main", tracker_id: 1, subject: ""
      })
      expect { cmd.create }.to raise_error(Rdm::ValidationError, /Subject cannot be blank/)
    end
  end

  describe "#update" do
    it "updates an issue and re-fetches on 204" do
      stub_request(:put, "https://redmine.example.com/issues/123.json")
        .to_return(status: 204, body: "", headers: {})

      stub_request(:get, "https://redmine.example.com/issues/123.json")
        .to_return(status: 200, body: {
          "issue" => { "id" => 123, "subject" => "Updated",
                       "status" => { "id" => 3, "name" => "Resolved" } }
        }.to_json, headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], { format: "json", status_id: 3, notes: "Fixed" })
      expect { cmd.update("123") }.to output(/Resolved/).to_stdout
    end
  end

  describe "#delete" do
    it "requires --confirm flag" do
      cmd = described_class.new([], { format: "json", confirm: false })
      expect { cmd.delete("123") }.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(4)
      end
    end

    it "deletes with --confirm" do
      stub_request(:get, "https://redmine.example.com/issues/123.json")
        .to_return(status: 200, body: {
          "issue" => { "id" => 123, "subject" => "To delete" }
        }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:delete, "https://redmine.example.com/issues/123.json")
        .to_return(status: 200, body: "", headers: {})

      cmd = described_class.new([], { format: "json", confirm: true })
      expect { cmd.delete("123") }.to output(/Deleted issue/).to_stdout
    end
  end

  describe "#copy" do
    it "copies an issue to another project" do
      # Fetch source
      stub_request(:get, "https://redmine.example.com/issues/100.json")
        .to_return(status: 200, body: {
          "issue" => {
            "id" => 100, "subject" => "Original",
            "description" => "Original desc",
            "tracker" => { "id" => 1, "name" => "Bug" },
            "priority" => { "id" => 2, "name" => "Normal" },
            "project" => { "id" => 1, "name" => "Source" }
          }
        }.to_json, headers: { "Content-Type" => "application/json" })

      # Create copy
      stub_request(:post, "https://redmine.example.com/issues.json")
        .to_return(status: 201, body: {
          "issue" => { "id" => 101, "subject" => "Original",
                       "project" => { "id" => 2, "name" => "Target" },
                       "tracker" => { "id" => 1, "name" => "Bug" } }
        }.to_json, headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], { format: "json", project_id: "target", link: false })
      expect { cmd.copy("100") }.to output(/101/).to_stdout
    end
  end

  describe "#journals" do
    it "lists issue journals" do
      stub_request(:get, "https://redmine.example.com/issues/123.json")
        .with(query: hash_including("include" => "journals"))
        .to_return(status: 200, body: {
          "issue" => {
            "id" => 123,
            "journals" => [
              { "id" => 1, "user" => { "name" => "Admin" }, "notes" => "Fixed",
                "created_on" => "2026-03-22", "details" => [] }
            ]
          }
        }.to_json, headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], { format: "json" })
      expect { cmd.journals("123") }.to output(/Fixed/).to_stdout
    end
  end
end

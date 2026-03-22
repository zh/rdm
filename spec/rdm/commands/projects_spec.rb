# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Rdm::Commands::Projects do
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

    config = Rdm::Config.new(config_path)
    config.save_profile(url: "https://redmine.example.com", api_key: "test_key")
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#list" do
    it "lists projects" do
      stub_request(:get, "https://redmine.example.com/projects.json")
        .with(query: hash_including("limit" => "25"))
        .to_return(status: 200, body: {
          "projects" => [
            { "id" => 1, "name" => "Project A", "identifier" => "project-a",
              "status" => 1, "created_on" => "2026-01-01" },
            { "id" => 2, "name" => "Project B", "identifier" => "project-b",
              "status" => 1, "created_on" => "2026-02-01" }
          ],
          "total_count" => 2
        }.to_json, headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], { format: "json", limit: 25, offset: 0 })
      expect { cmd.list }.to output(/Project A/).to_stdout
    end

    it "filters by status" do
      stub_request(:get, "https://redmine.example.com/projects.json")
        .with(query: hash_including("status" => "1"))
        .to_return(status: 200, body: { "projects" => [], "total_count" => 0 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], { format: "json", status: "active", limit: 25, offset: 0 })
      expect { cmd.list }.to output.to_stdout
    end
  end

  describe "#show" do
    it "shows project details" do
      stub_request(:get, "https://redmine.example.com/projects/myproject.json")
        .to_return(status: 200, body: {
          "project" => {
            "id" => 1, "name" => "My Project", "identifier" => "myproject",
            "description" => "A test project", "status" => 1,
            "is_public" => true, "created_on" => "2026-01-01"
          }
        }.to_json, headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], { format: "json" })
      expect { cmd.show("myproject") }.to output(/My Project/).to_stdout
    end
  end

  describe "#create" do
    it "creates a project" do
      stub_request(:post, "https://redmine.example.com/projects.json")
        .with(body: hash_including("project" => hash_including("name" => "New Project")))
        .to_return(status: 201, body: {
          "project" => {
            "id" => 10, "name" => "New Project", "identifier" => "new-project",
            "status" => 1
          }
        }.to_json, headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], {
        format: "json", name: "New Project", identifier: "new-project"
      })
      expect { cmd.create }.to output(/New Project/).to_stdout
    end
  end

  describe "#update" do
    it "updates and re-fetches project" do
      stub_request(:put, "https://redmine.example.com/projects/1.json")
        .to_return(status: 204, body: "", headers: {})

      stub_request(:get, "https://redmine.example.com/projects/1.json")
        .to_return(status: 200, body: {
          "project" => { "id" => 1, "name" => "Updated Name", "identifier" => "proj" }
        }.to_json, headers: { "Content-Type" => "application/json" })

      cmd = described_class.new([], { format: "json", name: "Updated Name" })
      expect { cmd.update("1") }.to output(/Updated Name/).to_stdout
    end

    it "exits when no fields provided" do
      cmd = described_class.new([], { format: "json" })
      expect { cmd.update("1") }.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(4)
      end
    end
  end

  describe "#delete" do
    it "requires --confirm" do
      cmd = described_class.new([], { format: "json", confirm: false })
      expect { cmd.delete("1") }.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(4)
      end
    end

    it "deletes with --confirm" do
      stub_request(:get, "https://redmine.example.com/projects/1.json")
        .to_return(status: 200, body: {
          "project" => { "id" => 1, "name" => "Doomed" }
        }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:delete, "https://redmine.example.com/projects/1.json")
        .to_return(status: 200, body: "", headers: {})

      cmd = described_class.new([], { format: "json", confirm: true })
      expect { cmd.delete("1") }.to output(/Deleted project/).to_stdout
    end
  end
end

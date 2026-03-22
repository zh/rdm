# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rdm::Client do
  let(:client) { build_test_client }

  describe "#get" do
    it "sends GET request with API key header" do
      stub_redmine(:get, "/issues.json", body: { "issues" => [], "total_count" => 0 })

      result = client.get("/issues")

      expect(result["issues"]).to eq([])
      expect(WebMock).to have_requested(:get, "#{test_base_url}/issues.json")
        .with(headers: { "X-Redmine-API-Key" => test_api_key })
    end

    it "appends .json extension to paths" do
      stub_redmine(:get, "/projects.json", body: { "projects" => [] })

      client.get("/projects")

      expect(WebMock).to have_requested(:get, "#{test_base_url}/projects.json")
    end

    it "does not double-append .json" do
      stub_redmine(:get, "/projects.json", body: { "projects" => [] })

      client.get("/projects.json")

      expect(WebMock).to have_requested(:get, "#{test_base_url}/projects.json")
    end

    it "sends query parameters" do
      stub_request(:get, "#{test_base_url}/issues.json?project_id=1&limit=10")
        .to_return(status: 200, body: { "issues" => [] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      client.get("/issues", { project_id: 1, limit: 10 })

      expect(WebMock).to have_requested(:get, "#{test_base_url}/issues.json")
        .with(query: { "project_id" => "1", "limit" => "10" })
    end
  end

  describe "#post" do
    it "sends POST with JSON body wrapped in envelope" do
      stub_redmine(:post, "/issues.json", status: 201, body: {
        "issue" => { "id" => 1, "subject" => "Test" }
      })

      result = client.post("/issues", { issue: { subject: "Test", project_id: 1 } })

      expect(result["issue"]["id"]).to eq(1)
      expect(WebMock).to have_requested(:post, "#{test_base_url}/issues.json")
        .with(body: { issue: { subject: "Test", project_id: 1 } }.to_json)
    end
  end

  describe "#put" do
    it "handles 204 empty response" do
      stub_redmine(:put, "/issues/1.json", status: 204, body: "")

      result = client.put("/issues/1", { issue: { status_id: 3 } })

      expect(result).to eq({})
    end
  end

  describe "#delete" do
    it "sends DELETE request" do
      stub_redmine(:delete, "/issues/1.json", status: 200, body: "")

      result = client.delete("/issues/1")

      expect(result).to eq({})
    end
  end

  describe "error handling" do
    it "raises AuthError on 401" do
      stub_redmine(:get, "/issues.json", status: 401, body: { "error" => "Unauthorized" })

      expect { client.get("/issues") }.to raise_error(Rdm::AuthError) do |e|
        expect(e.status).to eq(401)
      end
    end

    it "raises ForbiddenError on 403" do
      stub_redmine(:get, "/issues.json", status: 403, body: { "error" => "Forbidden" })

      expect { client.get("/issues") }.to raise_error(Rdm::ForbiddenError) do |e|
        expect(e.status).to eq(403)
      end
    end

    it "raises NotFoundError on 404" do
      stub_redmine(:get, "/issues/99999.json", status: 404, body: "")

      expect { client.get("/issues/99999") }.to raise_error(Rdm::NotFoundError) do |e|
        expect(e.status).to eq(404)
      end
    end

    it "raises ValidationError on 422 with error details" do
      stub_redmine(:post, "/issues.json", status: 422, body: {
        "errors" => ["Subject cannot be blank", "Tracker is invalid"]
      })

      expect { client.post("/issues", { issue: {} }) }.to raise_error(Rdm::ValidationError) do |e|
        expect(e.status).to eq(422)
        expect(e.errors).to include("Subject cannot be blank")
        expect(e.message).to include("Subject cannot be blank")
      end
    end

    it "raises ServerError on 500" do
      stub_redmine(:get, "/issues.json", status: 500, body: "Internal Server Error")

      expect { client.get("/issues") }.to raise_error(Rdm::ServerError) do |e|
        expect(e.status).to eq(500)
      end
    end

    it "raises ConnectionError on connection failure" do
      stub_request(:get, "#{test_base_url}/issues.json").to_raise(Faraday::ConnectionFailed.new("refused"))

      expect { client.get("/issues") }.to raise_error(Rdm::ConnectionError, /Cannot connect/)
    end

    it "raises TimeoutError on timeout" do
      stub_request(:get, "#{test_base_url}/issues.json").to_raise(Faraday::TimeoutError.new("timed out"))

      expect { client.get("/issues") }.to raise_error(Rdm::TimeoutError)
    end
  end

  describe "#test_connection" do
    it "returns user data on success" do
      stub_redmine(:get, "/users/current.json", body: {
        "user" => { "id" => 1, "login" => "admin", "firstname" => "Admin", "lastname" => "User" }
      })

      user = client.test_connection
      expect(user["login"]).to eq("admin")
    end

    it "raises AuthError with invalid key" do
      stub_redmine(:get, "/users/current.json", status: 401, body: { "error" => "Unauthorized" })

      expect { client.test_connection }.to raise_error(Rdm::AuthError)
    end
  end

  describe "#paginate" do
    it "fetches all pages" do
      stub_request(:get, "#{test_base_url}/issues.json")
        .with(query: hash_including("offset" => "0", "limit" => "2"))
        .to_return(status: 200, body: {
          "issues" => [{ "id" => 1 }, { "id" => 2 }], "total_count" => 3, "limit" => 2, "offset" => 0
        }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:get, "#{test_base_url}/issues.json")
        .with(query: hash_including("offset" => "2", "limit" => "2"))
        .to_return(status: 200, body: {
          "issues" => [{ "id" => 3 }], "total_count" => 3, "limit" => 2, "offset" => 2
        }.to_json, headers: { "Content-Type" => "application/json" })

      items = client.paginate("/issues", {}, limit: 2)
      expect(items.map { |i| i["id"] }).to eq([1, 2, 3])
    end

    it "yields pages when block given" do
      stub_request(:get, "#{test_base_url}/issues.json")
        .with(query: hash_including("offset" => "0"))
        .to_return(status: 200, body: {
          "issues" => [{ "id" => 1 }], "total_count" => 1
        }.to_json, headers: { "Content-Type" => "application/json" })

      pages = []
      client.paginate("/issues", {}, limit: 25) do |items, offset, total|
        pages << { items: items, offset: offset, total: total }
      end

      expect(pages.length).to eq(1)
      expect(pages.first[:total]).to eq(1)
    end
  end

  describe "User-Agent header" do
    it "includes rdm version" do
      stub_redmine(:get, "/issues.json", body: { "issues" => [] })

      client.get("/issues")

      expect(WebMock).to have_requested(:get, "#{test_base_url}/issues.json")
        .with(headers: { "User-Agent" => "rdm/#{Rdm::VERSION}" })
    end
  end
end

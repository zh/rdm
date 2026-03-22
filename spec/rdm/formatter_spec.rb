# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rdm::Formatter do
  describe ".output" do
    context "with JSON format" do
      it "renders pretty JSON for an array" do
        data = [{ "id" => 1, "name" => "Test" }]
        result = described_class.output(data, format: :json)
        parsed = JSON.parse(result)
        expect(parsed.first["id"]).to eq(1)
      end

      it "renders pretty JSON for a hash" do
        data = { "id" => 1, "name" => "Test" }
        result = described_class.output(data, format: :json)
        parsed = JSON.parse(result)
        expect(parsed["id"]).to eq(1)
      end
    end

    context "with table format" do
      it "renders a table with headers" do
        data = [
          { "id" => 1, "name" => "Project A" },
          { "id" => 2, "name" => "Project B" }
        ]
        result = described_class.output(data, format: :table, columns: %w[id name])
        expect(result).to include("Id")
        expect(result).to include("Name")
        expect(result).to include("Project A")
        expect(result).to include("Project B")
        expect(result).to include("--")
      end

      it "returns no results message for empty data" do
        result = described_class.output([], format: :table)
        expect(result).to eq("(no results)")
      end

      it "extracts nested Redmine objects" do
        data = [
          { "id" => 1, "tracker" => { "id" => 2, "name" => "Bug" }, "status" => { "id" => 1, "name" => "New" } }
        ]
        result = described_class.output(data, format: :table, columns: %w[id tracker status])
        expect(result).to include("Bug")
        expect(result).to include("New")
      end

      it "truncates long values" do
        data = [{ "id" => 1, "name" => "A" * 100 }]
        result = described_class.output(data, format: :table, columns: %w[id name])
        # Should not exceed 60 chars per column
        lines = result.split("\n")
        data_line = lines.last
        # The name column value should be truncated
        expect(data_line.length).to be < 200
      end
    end

    context "with CSV format" do
      it "renders CSV with headers" do
        data = [
          { "id" => 1, "name" => "Project A" },
          { "id" => 2, "name" => "Project B" }
        ]
        result = described_class.output(data, format: :csv, columns: %w[id name])
        lines = result.split("\n")
        expect(lines[0]).to eq("id,name")
        expect(lines[1]).to eq("1,Project A")
        expect(lines[2]).to eq("2,Project B")
      end

      it "quotes values containing commas" do
        data = [{ "id" => 1, "name" => "Project, with comma" }]
        result = described_class.output(data, format: :csv, columns: %w[id name])
        expect(result).to include('"Project, with comma"')
      end

      it "returns empty string for empty data" do
        result = described_class.output([], format: :csv)
        expect(result).to eq("")
      end
    end
  end

  describe ".detail" do
    it "renders key-value pairs" do
      data = { "id" => 42, "subject" => "Fix the bug", "status" => { "id" => 1, "name" => "New" } }
      result = described_class.detail(data, fields: %w[id subject status])
      expect(result).to include("Id")
      expect(result).to include("42")
      expect(result).to include("Subject")
      expect(result).to include("Fix the bug")
      expect(result).to include("Status")
      expect(result).to include("New")
    end

    it "skips nil values" do
      data = { "id" => 42, "name" => nil }
      result = described_class.detail(data, fields: %w[id name])
      expect(result).to include("42")
      expect(result).not_to include("Name")
    end
  end

  describe ".auto_format" do
    it "returns :table for TTY" do
      allow($stdout).to receive(:tty?).and_return(true)
      expect(described_class.auto_format).to eq(:table)
    end

    it "returns :json for non-TTY" do
      allow($stdout).to receive(:tty?).and_return(false)
      expect(described_class.auto_format).to eq(:json)
    end
  end
end

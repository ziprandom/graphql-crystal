# coding: utf-8
require "../spec_helper"
enum Cities
  London
  Leipzig
  BuenosAires
  Istanbul
end

class MyCityType < GraphQL::EnumType(Cities); end

describe GraphQL::Type do
  describe GraphQL::EnumType do
    subject = MyCityType
    input = GraphQL::Language::AEnum.new(name: "Leipzig")

    it "accepts an enum value as string" do
      subject.accepts?(input).should eq true
    end

    it "converts an enum value to a enum" do
      subject.prepare(input).should eq 1
    end

  end
end

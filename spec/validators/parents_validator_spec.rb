require 'rails_helper'

RSpec.describe Person, type: :model do
  fixtures :people, :marriages

  describe "ParentsValidator" do

    it "validates father can't be oneself" do
      person = people(:edward_iii)
      person.father = person
      person.validate
      expect(person.errors[:parent]).to include("can't be oneself")

      person.father = nil
      person.validate
      expect(person.errors[:parent]).to_not include("can't be oneself")
    end

    it "validates father is male" do
      person = people(:edward_iii)
      person.father = people(:unconnected_female)
      person.validate
      expect(person.errors[:father]).to include("must be male")

      person.father = people(:unconnected_male)
      person.validate
      expect(person.errors[:parent]).to_not include("must be male")
    end

    it "validates can't be husband" do
      person = people(:elizabeth_woodville)
      person.father = people(:edward_iv)
      person.validate
      expect(person.errors[:parent]).to include("can't be a spouse")

      person.father = people(:unconnected_male)
      person.validate
      expect(person.errors[:parent]).to_not include("can't be a spouse")
    end

    it "validates father can't be descendant" do
      person = people(:edward_iii)
      person.father = people(:henry_v)
      person.validate
      expect(person.errors[:parent]).to include("can't be a descendant")

      person.father = people(:unconnected_male)
      person.validate
      expect(person.errors[:parent]).to_not include("can't be a descendant")
    end

    it "validates mother can't be oneself" do
      person = people(:philippa)
      person.mother = person
      person.validate
      expect(person.errors[:parent]).to include("can't be oneself")

      person.mother = nil
      person.validate
      expect(person.errors[:parent]).to_not include("can't be oneself")
    end

    it "validates mother is female" do
      person = people(:edward_iii)
      person.mother = people(:unconnected_male)
      person.validate
      expect(person.errors[:mother]).to include("must be female")

      person.mother = people(:unconnected_female)
      person.validate
      expect(person.errors[:parent]).to_not include("must be female")
    end

    it "validates can't be wife" do
      person = people(:edward_iv)
      person.mother = people(:elizabeth_woodville)
      person.validate
      expect(person.errors[:parent]).to include("can't be a spouse")

      person.mother = people(:unconnected_female)
      person.validate
      expect(person.errors[:parent]).to_not include("can't be a spouse")
    end

    it "validates mother can't be descendant" do
      person = people(:edward_iii)
      person.mother = people(:margaret_beaufort)
      person.validate
      expect(person.errors[:parent]).to include("can't be a descendant")

      person.mother = people(:unconnected_female)
      person.validate
      expect(person.errors[:parent]).to_not include("can't be a descendant")
    end
  
  end
end
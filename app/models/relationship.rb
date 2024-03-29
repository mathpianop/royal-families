module Relationship

  def relationship_info(person)
    ancestry_connection = ancestry_connection(self, person)
    if (ancestry_connection)
      blood_relationship_info(ancestry_connection, person)
    else
      {relationship: relationship_by_marriage(self, person)}
    end
  end

  private 


  def relationship_is_direct(ancestry_connection, person)
    ancestry_connection[:lowest_common_ancestors].any? do |ancestor_id|
      ancestor_id == self.id || ancestor_id == person.id
    end
  end

  def blood_relationship_info(ancestry_connection, person)
    if relationship_is_direct(ancestry_connection, person)
      {relationship: blood_relationship(ancestry_connection)}
    else
      {
        relationship: blood_relationship(ancestry_connection),
        lowest_common_ancestors: self.class.where(id: ancestry_connection[:lowest_common_ancestors]).select(:name, :id)
      }
    end
  end


  # This query methods are modeled after the lowest_common_ancestors method in the genealogy gem
  # https://github.com/masciugo/genealogy

  def ancestry_connection(person_1, person_2)
    parent_ids_store = [[[person_1.id]], [[person_2.id]]]
    parent_ids_temp = [[person_1.id], [person_2.id]]
    
    while parent_ids_temp.any? {|ids| ids.length > 0}
      
      next_gen_ids = parent_ids_temp.map do |ids| 
        self.class.where(id: ids)
                  .select(:father_id, :mother_id)
                  .map{|result| [result.father_id, result.mother_id]}
                  .flatten
                  .compact 
      end

      next_gen_ids.each_with_index do |ids, index|
        parent_ids_store[index] << ids
        parent_ids_temp[index] = ids
      end
          
      possible_lowest_common_ancestors = parent_ids_store.map(&:flatten).reduce(:&)
      if possible_lowest_common_ancestors.length > 0
        return {
          # Striated ancestors ids is a 3-D array. Each 1st-level array corresponds to each person.
          # Each 2nd-level array represents a generation, 
          # containing two 3rd-level arrays for the ancestors of each parent at that generation level.
          striated_ancestor_ids: parent_ids_store, 
          lowest_common_ancestors: possible_lowest_common_ancestors,
          sex: person_2.sex
        }
      end
    end
    nil
  end


  def generation_counts(ancestry_connection)
    ancestry_connection[:striated_ancestor_ids].map do |generations| 
      generations.index {|generation| generation.include?(ancestry_connection[:lowest_common_ancestors][0])}
    end
  end

  def blood_relationship(ancestry_connection)
    counts = generation_counts(ancestry_connection)
    return "Self" if counts[0] == 0 && counts[1] == 0
    if counts.min == 0
      direct_relationship(counts, ancestry_connection)
    elsif counts.min > 0
      indirect_relationship(counts, ancestry_connection)
    end
  end

  def direct_relationship(generation_counts, ancestry_connection)
    sex = ancestry_connection[:sex]
    if generation_counts[0] == 0
      root_relationship = descendant_relationship((generation_counts[1] - generation_counts[0]), sex)
    elsif generation_counts[1] == 0
      root_relationship = ancestor_relationship((generation_counts[0] - generation_counts[1]), sex)
    end
    root_plus_greats(root_relationship, generation_counts)
  end

  def descendant_relationship(generation_gap, sex)
    if generation_gap == 1
      sex == "M" ? "son" : "daughter"
    elsif generation_gap > 1
      sex == "M" ? "grandson" : "daughter"
    end
  end

  def ancestor_relationship(generation_gap, sex)
    if generation_gap == 1
      sex == "F" ? "mother" : "father"
    elsif generation_gap > 1
      sex == "F" ? "grandmother" : "grandfather"
    end
  end

  def indirect_relationship(generation_counts, ancestry_connection)
    sex = ancestry_connection[:sex]
    if generation_counts.min == 1
      #sibling, auntcle, great-auntcle, neicphew, great-neicphiew, etc....
      root_relationship = neo_sibling_relationship(generation_counts, sex)
    elsif generation_counts.min > 1
      root_relationship = cousin_relationship(generation_counts)
    end

    if ancestry_connection[:lowest_common_ancestors].length == 1
      return "half #{root_relationship}"
    else
      return root_relationship
    end
  end

  def neo_sibling_relationship(generation_counts, sex)
   if generation_counts.all?(1)
    sibling_relationship(sex)
   else
    auntcle_relationship(generation_counts, sex)
   end
  end

  def sibling_relationship(sex)
    sex == "M" ? "brother" : "sister"
  end

  def auntcle_relationship(generation_counts, sex)
    if generation_counts[0] == 1
      root_relationship = (sex == "F" ? "neice" : "nephew")
    elsif generation_counts[1] == 1
      root_relationship = (sex == "F" ? "aunt" : "uncle")
    end

    root_plus_greats(root_relationship, generation_counts)
  end


  def root_plus_greats(root, generation_counts)
    num_of_greats = generation_counts.max - 2
    num_of_greats > 0  ? "#{"great-"*num_of_greats}#{root}" : root
  end
  

  def cousin_relationship(generation_counts)
    number_of_times = ["once", "twice"]
    removal = generation_counts.max - generation_counts.min
    root_relationship = "#{(generation_counts.min - 1).ordinalize} cousin"
    root_relationship += " #{number_of_times[removal - 1]} removed" if removal == 1 || removal == 2
    root_relationship += " #{removal} times removed" if removal > 2
    root_relationship
  end

  def relationship_by_marriage(person_1, person_2)
    if spouse_relationship?(person_1, person_2)
      person_2.sex == "M" ? "husband" : "wife"
    elsif child_in_law_relationship?(person_1, person_2)
      person_2.sex == "M" ? "son-in-law" : "daughter-in-law"
    elsif child_in_law_relationship?(person_2, person_1)
      person_2.sex == "M" ? "father-in-law" : "mother-in-law"
    elsif sibling_in_law_relationship?(person_1, person_2)
      person_2.sex == "M" ? "brother-in-law" : "sister-in-law"
    end
  end

  def child_in_law_relationship?(person_1, person_2)
    parent_id = person_1.parent_id_name
    children_in_law_ids = Person.joins(:consorts).where(consorts: {parent_id => person_1.id}).pluck(:id)
    children_in_law_ids.include?(person_2.id)
  end

  def spouse_relationship?(person_1, person_2)
    person_1.consorts.pluck(:id).include?(person_2.id)
  end

  def sibling_in_law_relationship?(person_1, person_2)
    siblings_of_spouses = self.class.joins(:consorts)
                                    .where(consorts: {father_id: person_2.father_id, mother_id: person_2.mother_id})
                                    .where.not(consorts: {father_id: nil, mother_id: nil})
    spouses_of_siblings = self.class.joins(:consorts)
                                    .where(consorts: {father_id: person_1.father_id, mother_id: person_1.mother_id})
                                    .where.not(consorts: {father_id: nil, mother_id: nil})
    sibling_in_law_ids = siblings_of_spouses.or(spouses_of_siblings).pluck(:id)
    sibling_in_law_ids.include?(person_1.id) || sibling_in_law_ids.include?(person_2.id)
  end
end